"""Shared authentication and authorization helpers for service-role endpoints.

The service-role client bypasses RLS. Every route using it must verify the
caller and the requested class before doing privileged work.
"""
import os
from typing import Any, Optional

from fastapi import Header, HTTPException
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError("Missing Supabase service configuration")

supabase_admin = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


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


def _profile_role(user_id: str) -> Optional[str]:
    result = (
        supabase_admin.table("profiles")
        .select("role")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    return (result.data or {}).get("role")


def ensure_teacher_owns_class(user_id: str, class_id: str) -> None:
    if _profile_role(user_id) != "teacher":
        raise HTTPException(status_code=403, detail="Teacher account required")

    result = (
        supabase_admin.table("classes")
        .select("id")
        .eq("id", class_id)
        .eq("created_by", user_id)
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=403, detail="You do not own this class")


def ensure_class_access(user_id: str, class_id: str) -> None:
    if _profile_role(user_id) == "teacher":
        owned = (
            supabase_admin.table("classes")
            .select("id")
            .eq("id", class_id)
            .eq("created_by", user_id)
            .maybe_single()
            .execute()
        )
        if owned.data:
            return

    membership = (
        supabase_admin.table("class_members")
        .select("id")
        .eq("class_id", class_id)
        .eq("user_id", user_id)
        .eq("student", True)
        .maybe_single()
        .execute()
    )
    if not membership.data:
        raise HTTPException(status_code=403, detail="Class membership required")
