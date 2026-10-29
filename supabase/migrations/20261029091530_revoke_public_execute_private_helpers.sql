-- Revoke default PUBLIC execution on internal helper functions.
-- Authenticated still has EXECUTE on the helper functions for RLS policy use,
-- while anon/PUBLIC cannot invoke them if the private schema is ever exposed.
begin;

revoke all on function private.is_teacher_user(uuid) from public, anon;
revoke all on function private.is_class_teacher(uuid, uuid) from public, anon;
revoke all on function private.is_class_teacher_text(text, uuid) from public, anon;
revoke all on function private.is_class_member(uuid, uuid) from public, anon;
revoke all on function private.is_teacher_of_student(uuid, uuid) from public, anon;
revoke all on function private.storage_reference_path(text, text) from public, anon;

commit;
