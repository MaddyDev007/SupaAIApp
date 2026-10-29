-- Restore class-scoped permissions: one account may own classes and join
-- other classes as a member. Global profiles.role must not block either action.

begin;

drop policy if exists classes_insert_teacher_owner on public.classes;
drop policy if exists classes_insert_authenticated_owner on public.classes;
create policy classes_insert_authenticated_owner
on public.classes for insert to authenticated
with check (created_by = (select auth.uid()));

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

revoke all on function public.join_class_by_code(text) from public, anon;
grant execute on function public.join_class_by_code(text) to authenticated;

commit;
