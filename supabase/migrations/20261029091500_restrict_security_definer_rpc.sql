-- Restrict security-definer helpers to internal policy/trigger usage.
-- Public RPCs remain limited to join_class_by_code and get_class_quizzes.
begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_teacher_user(p_user_id uuid default auth.uid())
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
      and p_user_id = auth.uid()
      and p.role = 'teacher'
  );
$$;

create or replace function private.is_class_teacher(
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
      and p_user_id = auth.uid()
      and c.created_by = p_user_id
  );
$$;

create or replace function private.is_class_teacher_text(
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
      and p_user_id = auth.uid()
      and c.created_by = p_user_id
  );
$$;

create or replace function private.is_class_member(
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
      and p_user_id = auth.uid()
      and cm.user_id = p_user_id
      and cm.student = true
  );
$$;

create or replace function private.is_teacher_of_student(
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
      and p_teacher_id = auth.uid()
      and c.created_by = p_teacher_id
  );
$$;

create or replace function private.storage_reference_path(
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

create or replace function private.handle_new_auth_user_smartclass()
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
      and (
        pg_catalog.lower(coalesce(new.email, '')) like '%@myclg.edu'
        or exists (
          select 1 from public.classes c where c.created_by = new.id
        )
      )
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
    -- Role is derived only from a verified college-domain email. This also
    -- demotes teachers if their account email changes away from that domain.
    update public.profiles
    set email = new.email,
        role = case
          when new.email_confirmed_at is not null
            and (
              pg_catalog.lower(coalesce(new.email, '')) like '%@myclg.edu'
              or exists (
                select 1 from public.classes c where c.created_by = new.id
              )
            )
            then 'teacher'
          else 'student'
        end
    where id = new.id;

    update public.users
    set email = new.email
    where id = new.id;
  end if;

  return new;
end;
$$;

create or replace function private.compute_quiz_result_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_questions jsonb;
  v_answers jsonb;
  v_user jsonb;
  v_quiz_class_id uuid;
  v_quiz_subject text;
  v_count integer;
  v_score integer := 0;
  v_index integer;
  v_correct integer;
  v_given integer;
begin
  select q.questions, q.class_id, q.subject
    into v_questions, v_quiz_class_id, v_quiz_subject
  from public.quizzes q
  where q.id = new.quiz_id;

  if not found or v_questions is null then
    raise exception 'Quiz not found or has no questions' using errcode = '23503';
  end if;

  if new.class_id is distinct from v_quiz_class_id then
    raise exception 'Result class does not match quiz class' using errcode = '23503';
  end if;

  if pg_catalog.jsonb_typeof(v_questions) = 'string' then
    v_questions := (v_questions #>> '{}')::jsonb;
  end if;
  if pg_catalog.jsonb_typeof(v_questions) is distinct from 'array' then
    raise exception 'Quiz question data is invalid' using errcode = '22023';
  end if;

  v_answers := new.answers;
  if pg_catalog.jsonb_typeof(v_answers) = 'string' then
    v_answers := (v_answers #>> '{}')::jsonb;
  end if;
  if pg_catalog.jsonb_typeof(v_answers) is distinct from 'array' then
    raise exception 'Answers must be a JSON array' using errcode = '22023';
  end if;

  v_count := pg_catalog.jsonb_array_length(v_questions);
  if v_count < 1 then
    raise exception 'Quiz has no questions' using errcode = '22023';
  end if;
  if pg_catalog.jsonb_array_length(v_answers) <> v_count then
    raise exception 'Answer count does not match quiz question count' using errcode = '22023';
  end if;

  for v_index in 0..v_count - 1 loop
    begin
      v_correct := (v_questions -> v_index ->> 'answer')::integer;
      v_given := (v_answers ->> v_index)::integer;
    exception when others then
      raise exception 'Quiz answer data is invalid' using errcode = '22023';
    end;
    if v_given = v_correct then
      v_score := v_score + 1;
    end if;
  end loop;

  select pg_catalog.to_jsonb(u) into v_user
  from (
    select us.name, us.avatar_url
    from public.users us
    where us.id = new.student_id
  ) u;

  new.subject := v_quiz_subject;
  new.score := v_score;
  new.total_questions := v_count;
  new.answers := v_answers;
  new.student_name := v_user ->> 'name';
  new.avatar_url := v_user ->> 'avatar_url';
  return new;
end;
$$;

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

  if private.is_teacher_user(v_user_id) then
    return pg_catalog.jsonb_build_object('status', 'teachers_cannot_join_as_student');
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

create or replace function public.get_class_quizzes(
  p_class_id uuid,
  p_quiz_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_questions jsonb;
  v_safe_questions jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if not (
    private.is_class_teacher(p_class_id, auth.uid())
    or private.is_class_member(p_class_id, auth.uid())
  ) then
    raise exception 'Class membership required' using errcode = '42501';
  end if;

  if p_quiz_id is null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', q.id,
          'subject', q.subject,
          'created_at', q.created_at
        )
        order by q.created_at desc
      ),
      '[]'::jsonb
    )
    into v_result
    from public.quizzes q
    where q.class_id = p_class_id;
    return v_result;
  end if;

  select q.questions
    into v_questions
  from public.quizzes q
  where q.id = p_quiz_id
    and q.class_id = p_class_id;

  if not found or v_questions is null then
    raise exception 'Quiz not found' using errcode = 'P0002';
  end if;

  if jsonb_typeof(v_questions) = 'string' then
    v_questions := (v_questions #>> '{}')::jsonb;
  end if;
  if jsonb_typeof(v_questions) is distinct from 'array' then
    raise exception 'Quiz question data is invalid' using errcode = '22023';
  end if;

  select coalesce(
    jsonb_agg(question_value - 'answer' order by ordinal_position),
    '[]'::jsonb
  )
  into v_safe_questions
  from jsonb_array_elements(v_questions) with ordinality
       as question_rows(question_value, ordinal_position);

  select jsonb_build_object(
    'id', q.id,
    'subject', q.subject,
    'created_at', q.created_at,
    'questions', v_safe_questions
  )
  into v_result
  from public.quizzes q
  where q.id = p_quiz_id
    and q.class_id = p_class_id;

  return v_result;
end;
$$;

-- Old public helper functions are no longer callable through PostgREST RPC.
revoke all on function public.is_teacher_user(uuid) from public, anon, authenticated;
revoke all on function public.is_class_teacher(uuid, uuid) from public, anon, authenticated;
revoke all on function public.is_class_teacher_text(text, uuid) from public, anon, authenticated;
revoke all on function public.is_class_member(uuid, uuid) from public, anon, authenticated;
revoke all on function public.is_teacher_of_student(uuid, uuid) from public, anon, authenticated;
revoke all on function public.storage_reference_path(text, text) from public, anon, authenticated;
revoke all on function public.handle_new_auth_user_smartclass() from public, anon, authenticated;
revoke all on function public.compute_quiz_result_before_insert() from public, anon, authenticated;
grant execute on function private.is_teacher_user(uuid) to authenticated;
grant execute on function private.is_class_teacher(uuid, uuid) to authenticated;
grant execute on function private.is_class_teacher_text(text, uuid) to authenticated;
grant execute on function private.is_class_member(uuid, uuid) to authenticated;
grant execute on function private.is_teacher_of_student(uuid, uuid) to authenticated;
grant execute on function private.storage_reference_path(text, text) to authenticated;
revoke all on function private.handle_new_auth_user_smartclass() from public, anon, authenticated;
revoke all on function private.compute_quiz_result_before_insert() from public, anon, authenticated;

-- Rebind trigger-only functions to the unexposed schema.
drop trigger if exists on_auth_user_created_smartclass on auth.users;
create trigger on_auth_user_created_smartclass
after insert or update on auth.users
for each row execute function private.handle_new_auth_user_smartclass();

drop trigger if exists compute_quiz_result_before_insert on public.results;
create trigger compute_quiz_result_before_insert
before insert on public.results
for each row execute function private.compute_quiz_result_before_insert();

drop policy if exists users_select_self_or_class_teacher on public.users;
create policy users_select_self_or_class_teacher
on public.users for select to authenticated
using (
  id = (select auth.uid())
  or private.is_teacher_of_student(id, (select auth.uid()))
);

drop policy if exists classes_select_authorized on public.classes;
create policy classes_select_authorized
on public.classes for select to authenticated
using (
  private.is_class_teacher(id, (select auth.uid()))
  or private.is_class_member(id, (select auth.uid()))
);

drop policy if exists classes_insert_teacher_owner on public.classes;
create policy classes_insert_teacher_owner
on public.classes for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.is_teacher_user((select auth.uid()))
);

drop policy if exists classes_delete_teacher_owner on public.classes;
create policy classes_delete_teacher_owner
on public.classes for delete to authenticated
using (private.is_class_teacher(id, (select auth.uid())));

drop policy if exists class_members_select_authorized on public.class_members;
create policy class_members_select_authorized
on public.class_members for select to authenticated
using (
  user_id = (select auth.uid())
  or private.is_class_teacher(class_id, (select auth.uid()))
);

drop policy if exists class_members_insert_teacher_self on public.class_members;
create policy class_members_insert_teacher_self
on public.class_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and student = false
  and private.is_class_teacher(class_id, (select auth.uid()))
);

drop policy if exists class_members_delete_authorized on public.class_members;
create policy class_members_delete_authorized
on public.class_members for delete to authenticated
using (
  user_id = (select auth.uid())
  or private.is_class_teacher(class_id, (select auth.uid()))
);

drop policy if exists materials_select_class_access on public.materials;
create policy materials_select_class_access
on public.materials for select to authenticated
using (
  private.is_class_teacher(class_id, (select auth.uid()))
  or private.is_class_member(class_id, (select auth.uid()))
);

drop policy if exists materials_insert_class_teacher on public.materials;
create policy materials_insert_class_teacher
on public.materials for insert to authenticated
with check (
  uploaded_by = (select auth.uid())
  and private.is_class_teacher(class_id, (select auth.uid()))
  and private.storage_reference_path(file_url, 'lessons')
      like 'materials/' || class_id::text || '/' || (select auth.uid())::text || '/%'
);

drop policy if exists materials_delete_class_teacher on public.materials;
create policy materials_delete_class_teacher
on public.materials for delete to authenticated
using (
  uploaded_by = (select auth.uid())
  and private.is_class_teacher(class_id, (select auth.uid()))
);

drop policy if exists questions_select_class_access on public.questions;
create policy questions_select_class_access
on public.questions for select to authenticated
using (
  private.is_class_teacher(class_id, (select auth.uid()))
  or private.is_class_member(class_id, (select auth.uid()))
);

drop policy if exists questions_delete_class_teacher on public.questions;
create policy questions_delete_class_teacher
on public.questions for delete to authenticated
using (private.is_class_teacher(class_id, (select auth.uid())));

drop policy if exists quizzes_select_class_teacher on public.quizzes;
create policy quizzes_select_class_teacher
on public.quizzes for select to authenticated
using (private.is_class_teacher(class_id, (select auth.uid())));

drop policy if exists results_select_student_or_teacher on public.results;
create policy results_select_student_or_teacher
on public.results for select to authenticated
using (
  student_id = (select auth.uid())
  or private.is_class_teacher(class_id, (select auth.uid()))
);

drop policy if exists results_insert_enrolled_student on public.results;
create policy results_insert_enrolled_student
on public.results for insert to authenticated
with check (
  student_id = (select auth.uid())
  and private.is_class_member(class_id, (select auth.uid()))
);

drop policy if exists results_delete_class_teacher on public.results;
create policy results_delete_class_teacher
on public.results for delete to authenticated
using (private.is_class_teacher(class_id, (select auth.uid())));

drop policy if exists notes_insert_owner on public.notes;
create policy notes_insert_owner
on public.notes for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    class_id is null
    or private.is_class_member(class_id, (select auth.uid()))
    or private.is_class_teacher(class_id, (select auth.uid()))
  )
);

drop policy if exists lessons_read_class_members on storage.objects;
create policy lessons_read_class_members
on storage.objects for select to authenticated
using (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (
    private.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
    or exists (
      select 1
      from public.class_members cm
      where cm.class_id::text = (storage.foldername(name))[2]
        and cm.user_id = (select auth.uid())
        and cm.student = true
    )
  )
);

drop policy if exists lessons_upload_class_teacher on storage.objects;
create policy lessons_upload_class_teacher
on storage.objects for insert to authenticated
with check (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (storage.foldername(name))[3] = (select auth.uid())::text
  and private.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
);

drop policy if exists lessons_update_class_teacher on storage.objects;
create policy lessons_update_class_teacher
on storage.objects for update to authenticated
using (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (storage.foldername(name))[3] = (select auth.uid())::text
  and private.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
)
with check (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and (storage.foldername(name))[3] = (select auth.uid())::text
  and private.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
);

drop policy if exists lessons_delete_class_teacher on storage.objects;
create policy lessons_delete_class_teacher
on storage.objects for delete to authenticated
using (
  bucket_id = 'lessons'
  and (storage.foldername(name))[1] = 'materials'
  and private.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
);

drop policy if exists questions_read_class_members on storage.objects;
create policy questions_read_class_members
on storage.objects for select to authenticated
using (
  bucket_id = 'questions'
  and (
    (
      (storage.foldername(name))[1] = 'classes'
      and (
        private.is_class_teacher_text((storage.foldername(name))[2], (select auth.uid()))
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
      where private.storage_reference_path(q.file_url, 'questions') = storage.objects.name
        and (
          private.is_class_teacher(q.class_id, (select auth.uid()))
          or private.is_class_member(q.class_id, (select auth.uid()))
        )
    )
  )
);

drop policy if exists questions_delete_class_teacher on storage.objects;
create policy questions_delete_class_teacher
on public.questions for delete to authenticated
using (private.is_class_teacher(class_id, (select auth.uid())));

drop policy if exists notes_read_owner on storage.objects;
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
        and private.storage_reference_path(n.image_url, 'notes') = storage.objects.name
    )
  )
);

drop policy if exists notes_upload_owner on storage.objects;
create policy notes_upload_owner
on storage.objects for insert to authenticated
with check (
  bucket_id = 'notes'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists notes_update_owner on storage.objects;
create policy notes_update_owner
on public.notes for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists notes_delete_owner on storage.objects;
create policy notes_delete_owner
on public.notes for delete to authenticated
using (user_id = (select auth.uid()));

commit;
