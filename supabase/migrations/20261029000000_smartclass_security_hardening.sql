-- SmartClassAI security hardening.
-- Review and test this migration before applying it to the live Supabase project.
-- It is intentionally committed as a draft; this file has NOT been executed on the database.

begin;

-- ---------------------------------------------------------------------------
-- Identity / ownership helpers. SECURITY DEFINER avoids RLS policy recursion.
-- Keep search_path empty and fully qualify object names.
-- ---------------------------------------------------------------------------
create or replace function public.is_teacher_user(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_user_id
      and p.role = 'teacher'
  );
$$;

create or replace function public.is_class_teacher(
  p_class_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classes c
    where c.id = p_class_id
      and c.created_by = p_user_id
  );
$$;

create or replace function public.is_class_teacher_text(
  p_class_id text,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classes c
    where c.id::text = p_class_id
      and c.created_by = p_user_id
  );
$$;

create or replace function public.is_class_member(
  p_class_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.class_members cm
    where cm.class_id = p_class_id
      and cm.user_id = p_user_id
      and cm.student = true
  );
$$;

create or replace function public.is_teacher_of_student(
  p_student_id uuid,
  p_teacher_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.class_members cm
    join public.classes c on c.id = cm.class_id
    where cm.user_id = p_student_id
      and cm.student = true
      and c.created_by = p_teacher_id
  );
$$;

-- Support both existing public-URL references and raw storage paths while
-- buckets transition to private. This function only parses a reference; it
-- never grants access by itself.
create or replace function public.storage_reference_path(
  p_reference text,
  p_bucket text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_reference is null or pg_catalog.btrim(p_reference) = '' then null
    when pg_catalog.strpos(p_reference, '://') = 0
      then pg_catalog.btrim(p_reference, '/')
    when pg_catalog.strpos(pg_catalog.split_part(p_reference, '?', 1), '/object/public/' || p_bucket || '/') > 0
      then pg_catalog.split_part(
        pg_catalog.split_part(p_reference, '/object/public/' || p_bucket || '/', 2),
        '?', 1
      )
    when pg_catalog.strpos(pg_catalog.split_part(p_reference, '?', 1), '/object/sign/' || p_bucket || '/') > 0
      then pg_catalog.split_part(
        pg_catalog.split_part(p_reference, '/object/sign/' || p_bucket || '/', 2),
        '?', 1
      )
    when pg_catalog.strpos(pg_catalog.split_part(p_reference, '?', 1), '/object/authenticated/' || p_bucket || '/') > 0
      then pg_catalog.split_part(
        pg_catalog.split_part(p_reference, '/object/authenticated/' || p_bucket || '/', 2),
        '?', 1
      )
    else null
  end;
$$;

-- Class join by invite code must not require listing all class codes.
create or replace function public.join_class_by_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_class public.classes%rowtype;
  v_user_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if pg_catalog.btrim(coalesce(p_code, '')) = '' then
    return pg_catalog.jsonb_build_object('status', 'not_found');
  end if;

  select c.*
    into v_class
  from public.classes c
  where c.code = pg_catalog.upper(pg_catalog.btrim(p_code))
  limit 1;

  if not found then
    return pg_catalog.jsonb_build_object('status', 'not_found');
  end if;

  if v_class.created_by = v_user_id then
    return pg_catalog.jsonb_build_object('status', 'already_owner');
  end if;

  if exists (
    select 1
    from public.class_members cm
    where cm.class_id = v_class.id
      and cm.user_id = v_user_id
  ) then
    return pg_catalog.jsonb_build_object('status', 'already_member');
  end if;

  select u.name into v_user_name
  from public.users u
  where u.id = v_user_id;

  insert into public.class_members (class_id, user_id, student, user_name)
  values (v_class.id, v_user_id, true, v_user_name);

  return pg_catalog.jsonb_build_object(
    'status', 'joined',
    'id', v_class.id,
    'name', v_class.name,
    'created_by', v_class.created_by
  );
end;
$$;

revoke all on function public.is_teacher_user(uuid) from public, anon;
revoke all on function public.is_class_teacher(uuid, uuid) from public, anon;
revoke all on function public.is_class_teacher_text(text, uuid) from public, anon;
revoke all on function public.is_class_member(uuid, uuid) from public, anon;
revoke all on function public.is_teacher_of_student(uuid, uuid) from public, anon;
revoke all on function public.storage_reference_path(text, text) from public, anon;
revoke all on function public.join_class_by_code(text) from public, anon;
grant execute on function public.is_teacher_user(uuid) to authenticated;
grant execute on function public.is_class_teacher(uuid, uuid) to authenticated;
grant execute on function public.is_class_teacher_text(text, uuid) to authenticated;
grant execute on function public.is_class_member(uuid, uuid) to authenticated;
grant execute on function public.is_teacher_of_student(uuid, uuid) to authenticated;
grant execute on function public.storage_reference_path(text, text) to authenticated;
grant execute on function public.join_class_by_code(text) to authenticated;

-- Signup currently tries to insert profile-only fields that do not exist and
-- may run before email confirmation creates an authenticated session. Create
-- the profile/user rows in a trusted trigger instead.
create or replace function public.handle_new_auth_user_smartclass()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_role text;
begin
  v_name := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(pg_catalog.split_part(coalesce(new.email, ''), '@', 1), ''),
    'User'
  );
  -- Do not grant the teacher role until the college-domain email is verified.
  v_role := case
    when new.email_confirmed_at is not null
      and pg_catalog.lower(coalesce(new.email, '')) like '%@myclg.edu'
      then 'teacher'
    else 'student'
  end;

  if tg_op = 'INSERT' then
    insert into public.profiles (id, email, role, name)
    values (new.id, new.email, v_role, v_name)
    on conflict (id) do nothing;

    insert into public.users (id, email, name, avatar_url)
    values (
      new.id,
      new.email,
      v_name,
      coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
    )
    on conflict (id) do nothing;
  elsif tg_op = 'UPDATE' then
    if old.email_confirmed_at is null
      and new.email_confirmed_at is not null
      and pg_catalog.lower(coalesce(new.email, '')) like '%@myclg.edu'
    then
      update public.profiles
      set role = 'teacher', email = new.email
      where id = new.id and role = 'student';
    end if;
  end if;

  return new;
end;
$;

drop trigger if exists on_auth_user_created_smartclass on auth.users;
create trigger on_auth_user_created_smartclass
after insert or update of email_confirmed_at on auth.users
for each row execute function public.handle_new_auth_user_smartclass();

-- Add missing rows for accounts created before this trigger existed; never
-- overwrite roles/profile edits already present.
insert into public.profiles (id, email, role, name)
select
  u.id,
  u.email,
  case
    when u.email_confirmed_at is not null
      and pg_catalog.lower(coalesce(u.email, '')) like '%@myclg.edu'
      then 'teacher'
    else 'student'
  end,
  coalesce(
    nullif(pg_catalog.btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(pg_catalog.btrim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(pg_catalog.split_part(coalesce(u.email, ''), '@', 1), ''),
    'User'
  )
from auth.users u
on conflict (id) do nothing;

-- Existing unverified or non-college teacher-role rows must not retain
-- privileged role access simply because an old client assigned the role.
update public.profiles p
set role = 'student'
from auth.users u
where p.id = u.id
  and p.role = 'teacher'
  and (
    u.email_confirmed_at is null
    or pg_catalog.lower(coalesce(u.email, '')) not like '%@myclg.edu'
  );

insert into public.users (id, email, name, avatar_url)
select
  u.id,
  u.email,
  coalesce(
    nullif(pg_catalog.btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(pg_catalog.btrim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(pg_catalog.split_part(coalesce(u.email, ''), '@', 1), ''),
    'User'
  ),
  coalesce(u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture')
from auth.users u
on conflict (id) do nothing;

-- Remove broad client-role table privileges. RLS policies below grant rows;
-- SQL privileges independently limit which actions each role can request.
revoke all on table public.profiles, public.users, public.classes,
  public.class_members, public.materials, public.questions, public.quizzes,
  public.results, public.notes from anon;

revoke all on table public.profiles, public.users, public.classes,
  public.class_members, public.materials, public.questions, public.quizzes,
  public.results, public.notes from authenticated;

grant select on table public.profiles, public.users, public.classes,
  public.class_members, public.materials, public.questions, public.quizzes,
  public.results, public.notes to authenticated;

grant update (name, department, year, reg_no) on public.profiles to authenticated;
grant insert (id, email, name, avatar_url, reg_no) on public.users to authenticated;
grant update (name, avatar_url, reg_no) on public.users to authenticated;
grant insert, delete on public.classes to authenticated;
grant insert, delete on public.class_members to authenticated;
grant insert, delete on public.materials to authenticated;
grant delete on public.questions to authenticated;
grant insert, delete on public.notes to authenticated;
grant update (title, content, color, image_url) on public.notes to authenticated;
grant insert, delete on public.results to authenticated;

-- Drop previous overly broad / duplicate policies before installing the
-- least-privilege set. This is intentionally explicit for the known schema.
drop policy if exists "Students can join class" on public.class_members;
drop policy if exists "Teacher can view class students" on public.class_members;
drop policy if exists class_members_insert_self on public.class_members;
drop policy if exists class_members_select_own on public.class_members;
drop policy if exists classes_insert_owner on public.classes;
drop policy if exists classes_select_by_code on public.classes;
drop policy if exists classes_select_if_member on public.classes;
drop policy if exists "Students and teachers can read quizzes" on public.quizzes;
drop policy if exists "Teacher can insert quizzes" on public.quizzes;
drop policy if exists "Teachers can insert quizzes" on public.quizzes;
drop policy if exists "Teachers can view their own quizzes" on public.quizzes;
drop policy if exists "Student can submit results only if enrolled" on public.results;
drop policy if exists "Students can read own results" on public.results;
drop policy if exists "Students can view their results" on public.results;
drop policy if exists "Students insert their results" on public.results;
drop policy if exists "Teacher can delete class results" on public.results;
drop policy if exists "Teacher can view class results" on public.results;

alter table public.profiles enable row level security;
alter table public.users enable row level security;
alter table public.classes enable row level security;
alter table public.class_members enable row level security;
alter table public.materials enable row level security;
alter table public.questions enable row level security;
alter table public.quizzes enable row level security;
alter table public.results enable row level security;
alter table public.notes enable row level security;

-- Profiles and user-directory rows.
drop policy if exists profiles_select_self on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_select_self
on public.profiles for select to authenticated
using (id = (select auth.uid()));

create policy profiles_update_self
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists users_select_self_or_class_teacher on public.users;
drop policy if exists users_insert_self on public.users;
drop policy if exists users_update_self on public.users;
create policy users_select_self_or_class_teacher
on public.users for select to authenticated
using (
  id = (select auth.uid())
  or public.is_teacher_of_student(id, (select auth.uid()))
);

create policy users_insert_self
on public.users for insert to authenticated
with check (
  id = (select auth.uid())
  and email = (select auth.jwt() ->> 'email')
);

create policy users_update_self
on public.users for update to authenticated
using (id = (select auth.uid()))
with check (
  id = (select auth.uid())
  and email = (select auth.jwt() ->> 'email')
);

-- Classes: members can see their classes; teachers can see their own classes.
-- Invite-code lookup happens through join_class_by_code(), not a class listing.
drop policy if exists classes_select_authorized on public.classes;
drop policy if exists classes_insert_teacher_owner on public.classes;
drop policy if exists classes_delete_teacher_owner on public.classes;
create policy classes_select_authorized
on public.classes for select to authenticated
using (
  public.is_class_teacher(id, (select auth.uid()))
  or public.is_class_member(id, (select auth.uid()))
);

create policy classes_insert_teacher_owner
on public.classes for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.is_teacher_user((select auth.uid()))
);

create policy classes_delete_teacher_owner
on public.classes for delete to authenticated
using (public.is_class_teacher(id, (select auth.uid())));

-- Membership: students can read their own membership; class owner sees class
-- students. Direct student inserts are denied; join_class_by_code() handles it.
drop policy if exists class_members_select_authorized on public.class_members;
drop policy if exists class_members_insert_teacher_self on public.class_members;
drop policy if exists class_members_delete_authorized on public.class_members;
create policy class_members_select_authorized
on public.class_members for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_class_teacher(class_id, (select auth.uid()))
);

create policy class_members_insert_teacher_self
on public.class_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and student = false
  and public.is_class_teacher(class_id, (select auth.uid()))
);

create policy class_members_delete_authorized
on public.class_members for delete to authenticated
using (
  user_id = (select auth.uid())
  or public.is_class_teacher(class_id, (select auth.uid()))
);

-- Materials are available only to the teacher who owns the class and enrolled
-- students. Uploads must live under materials/<class_id>/<teacher_id>/...
drop policy if exists materials_select_class_access on public.materials;
drop policy if exists materials_insert_class_teacher on public.materials;
drop policy if exists materials_delete_class_teacher on public.materials;
create policy materials_select_class_access
on public.materials for select to authenticated
using (
  public.is_class_teacher(class_id, (select auth.uid()))
  or public.is_class_member(class_id, (select auth.uid()))
);

create policy materials_insert_class_teacher
on public.materials for insert to authenticated
with check (
  uploaded_by = (select auth.uid())
  and public.is_class_teacher(class_id, (select auth.uid()))
  and public.storage_reference_path(file_url, 'lessons')
      like 'materials/' || class_id::text || '/' || (select auth.uid())::text || '/%'
);

create policy materials_delete_class_teacher
on public.materials for delete to authenticated
using (
  uploaded_by = (select auth.uid())
  and public.is_class_teacher(class_id, (select auth.uid()))
);

-- Questions/PDF banks: class-linked reads; only the class owner can delete.
-- Inserts are performed by the trusted backend service-role client.
drop policy if exists questions_select_class_access on public.questions;
drop policy if exists questions_delete_class_teacher on public.questions;
create policy questions_select_class_access
on public.questions for select to authenticated
using (
  public.is_class_teacher(class_id, (select auth.uid()))
  or public.is_class_member(class_id, (select auth.uid()))
);

create policy questions_delete_class_teacher
on public.questions for delete to authenticated
using (public.is_class_teacher(class_id, (select auth.uid())));

-- Quizzes can only be read by members of the associated class and its owner.
-- Server-side writes must independently verify the authenticated class owner.
drop policy if exists quizzes_select_class_access on public.quizzes;
create policy quizzes_select_class_access
on public.quizzes for select to authenticated
using (
  public.is_class_teacher(class_id, (select auth.uid()))
  or public.is_class_member(class_id, (select auth.uid()))
);

-- Results: a student can submit only their own result for a quiz in a class
-- they joined. A teacher can view/delete results for their own class.
drop policy if exists results_select_student_or_teacher on public.results;
drop policy if exists results_insert_enrolled_student on public.results;
drop policy if exists results_delete_class_teacher on public.results;
create policy results_select_student_or_teacher
on public.results for select to authenticated
using (
  student_id = (select auth.uid())
  or public.is_class_teacher(class_id, (select auth.uid()))
);

create policy results_insert_enrolled_student
on public.results for insert to authenticated
with check (
  student_id = (select auth.uid())
  and public.is_class_member(class_id, (select auth.uid()))
  and exists (
    select 1
    from public.quizzes q
    where q.id = results.quiz_id
      and q.class_id = results.class_id
  )
);

create policy results_delete_class_teacher
on public.results for delete to authenticated
using (public.is_class_teacher(class_id, (select auth.uid())));

-- Student notes are private to the note owner, regardless of class context.
drop policy if exists notes_select_owner on public.notes;
drop policy if exists notes_insert_owner on public.notes;
drop policy if exists notes_update_owner on public.notes;
drop policy if exists notes_delete_owner on public.notes;
create policy notes_select_owner
on public.notes for select to authenticated
using (user_id = (select auth.uid()));

create policy notes_insert_owner
on public.notes for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    class_id is null
    or public.is_class_member(class_id, (select auth.uid()))
    or public.is_class_teacher(class_id, (select auth.uid()))
  )
);

create policy notes_update_owner
on public.notes for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy notes_delete_owner
on public.notes for delete to authenticated
using (user_id = (select auth.uid()));

-- Storage access is private and scoped to class membership / note ownership.
-- Old lesson paths were materials/<class_id>/<filename>; new uploads add the
-- uploader ID as a third segment. Both remain class-scoped.
drop policy if exists "Allow teachers to upload to lessons" on storage.objects;
drop policy if exists "Teachers can manage their own lesson files 145d8b_0" on storage.objects;
drop policy if exists "Teachers can manage their own lesson files 145d8b_1" on storage.objects;
drop policy if exists "Teachers can manage their own lesson files 145d8b_2" on storage.objects;
drop policy if exists "Teachers can manage their own lesson files 15k0kst_0" on storage.objects;
drop policy if exists "Teachers can manage their own lesson files 15k0kst_1" on storage.objects;
drop policy if exists "Teachers can manage their own lesson files 15k0kst_2" on storage.objects;
drop policy if exists "Allow users to delete notes img 1qipc1_0" on storage.objects;
drop policy if exists "Allow users to delete notes img 1qipc1_1" on storage.objects;
drop policy if exists "Allow users to select notes images 1qipc1_0" on storage.objects;
drop policy if exists "Allow users to select notes images 1qipc1_1" on storage.objects;
drop policy if exists "Allow users to upload notes images 1qipc1_0" on storage.objects;

drop policy if exists lessons_read_class_members on storage.objects;
drop policy if exists lessons_upload_class_teacher on storage.objects;
drop policy if exists lessons_update_class_teacher on storage.objects;
drop policy if exists lessons_delete_class_teacher on storage.objects;
drop policy if exists questions_read_class_members on storage.objects;
drop policy if exists questions_delete_class_teacher on storage.objects;
drop policy if exists notes_read_owner on storage.objects;
drop policy if exists notes_upload_owner on storage.objects;
drop policy if exists notes_update_owner on storage.objects;
drop policy if exists notes_delete_owner on storage.objects;

create policy lessons_read_class_members
on storage.objects for select to authenticated
using (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (
    public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
    or exists (
      select 1
      from public.class_members cm
      where cm.class_id::text = (storage.foldername(name))[2]
        and cm.user_id = (select auth.uid())
        and cm.student = true
    )
  )
);

create policy lessons_upload_class_teacher
on storage.objects for insert to authenticated
with check (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (storage.foldername(name))[3] = (select auth.uid())::text
  and public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
);

create policy lessons_update_class_teacher
on storage.objects for update to authenticated
using (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (storage.foldername(name))[3] = (select auth.uid())::text
  and public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
)
with check (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (storage.foldername(name))[3] = (select auth.uid())::text
  and public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
);

create policy lessons_delete_class_teacher
on storage.objects for delete to authenticated
using (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
);

create policy questions_read_class_members
on storage.objects for select to authenticated
using (
  bucket_id = 'questions'
  and (
    (
      (storage.foldername(name))[1] = 'classes'
      and (
        public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
        or exists (
          select 1
          from public.class_members cm
          where cm.class_id::text = (storage.foldername(name))[2]
            and cm.user_id = (select auth.uid())
            and cm.student = true
        )
      )
    )
    or exists (
      select 1
      from public.questions q
      where public.storage_reference_path(q.file_url, 'questions') = storage.objects.name
        and (
          public.is_class_teacher(q.class_id, (select auth.uid()))
          or public.is_class_member(q.class_id, (select auth.uid()))
        )
    )
  )
);

create policy questions_delete_class_teacher
on storage.objects for delete to authenticated
using (
  bucket_id = 'questions'
  and (
    (
      (storage.foldername(name))[1] = 'classes'
      and public.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
    )
    or exists (
      select 1
      from public.questions q
      where public.storage_reference_path(q.file_url, 'questions') = storage.objects.name
        and public.is_class_teacher(q.class_id, (select auth.uid()))
    )
  )
);

create policy notes_read_owner
on storage.objects for select to authenticated
using (
  bucket_id = 'notes'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1
      from public.notes n
      where n.user_id = (select auth.uid())
        and public.storage_reference_path(n.image_url, 'notes') = storage.objects.name
    )
  )
);

create policy notes_upload_owner
on storage.objects for insert to authenticated
with check (
  bucket_id = 'notes'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy notes_update_owner
on storage.objects for update to authenticated
using (
  bucket_id = 'notes'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'notes'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy notes_delete_owner
on storage.objects for delete to authenticated
using (
  bucket_id = 'notes'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1
      from public.notes n
      where n.user_id = (select auth.uid())
        and public.storage_reference_path(n.image_url, 'notes') = storage.objects.name
    )
  )
);

-- Public buckets bypass storage.objects SELECT policies for URL reads. Switch
-- to private only as part of the coordinated code rollout described in README.
update storage.buckets
set public = false
where name in ('lessons', 'questions', 'notes');

commit;
