"""Shared authentication and authorization helpers for service-role endpoints.

The service-role client bypasses RLS. Every route using it must verify the
caller and the requested class before doing privileged work.

Class permissions are scoped to each class:
- The creator is the teacher/owner of that class.
- A user with a student membership can access that joined class.
A global profiles.role value must not prevent one account from doing both.
"""
from typing import Any, Optional

from fastapi import Header, HTTPException
from supabase import create_client

from config import get_settings


settings = get_settings()
supabase_admin = create_client(
    settings.supabase_url,
    settings.supabase_service_role_key,
)


def authenticated_user(authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer access token required")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Bearer access token required")

    try:
        response = supabase_admin.auth.get_user(token)
        user = getattr(response, "user", None)
        if user is None:
            raise HTTPException(status_code=401, detail="Invalid or expired session")
        return {"id": str(user.id), "email": user.email}
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired session")


def _query_has_row(query: Any) -> bool:
    """Execute a limited query without maybe_single() response-shape ambiguity."""
    response = query.limit(1).execute()

    # Supabase/PostgREST normally returns an APIResponse with .data. Be
    # defensive about None or unexpected wrappers so an empty lookup does
    # not turn into an AttributeError/500.
    data = getattr(response, "data", response)
    if data is None:
        return False
    if isinstance(data, (list, tuple)):
        return len(data) > 0
    return bool(data)


def _class_is_owned_by(user_id: str, class_id: str) -> bool:
    return _query_has_row(
        supabase_admin.table("classes")
        .select("id")
        .eq("id", class_id)
        .eq("created_by", user_id)
    )


def _is_student_member(user_id: str, class_id: str) -> bool:
    return _query_has_row(
        supabase_admin.table("class_members")
        .select("id")
        .eq("class_id", class_id)
        .eq("user_id", user_id)
        .eq("student", True)
    )


def ensure_teacher_owns_class(user_id: str, class_id: str) -> None:
    # Kept under its existing name for route compatibility. Ownership of the
    # requested class, not the account's global profile role, is authoritative.
    if not _class_is_owned_by(user_id, class_id):
        raise HTTPException(status_code=403, detail="You do not own this class")


def ensure_class_access(user_id: str, class_id: str) -> None:
    # Check ownership first for every account; then check joined-student access.
    # This allows the same account to own Class A and join Class B.
    if _class_is_owned_by(user_id, class_id):
        return

    if not _is_student_member(user_id, class_id):
        raise HTTPException(status_code=403, detail="Class membership required")
