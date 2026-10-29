from fastapi import APIRouter, HTTPException, Depends
from security import authenticated_user, ensure_teacher_owns_class
from services.private_storage import storage_path_from_reference
from supabase import create_client
from dotenv import load_dotenv
from pathlib import Path
import os

router = APIRouter()

# ✅ Load .env from backend root
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError("Missing Supabase environment variables")

# 🔐 Service-role Supabase client
supabase = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
)

# 🔁 Helper: convert public URL → storage path
def extract_storage_path(url: str, bucket: str) -> str:
    return storage_path_from_reference(url, bucket)


@router.delete("/class")
def delete_class(
    class_id: str,
    user: dict = Depends(authenticated_user),
):
    try:
        ensure_teacher_owns_class(user["id"], class_id)
        # 1️⃣ MATERIALS → lessons bucket
        materials = (
            supabase.table("materials")
            .select("file_url")
            .eq("class_id", class_id)
            .execute()
            .data
        )

        if materials:
            paths = [
                extract_storage_path(m["file_url"], "lessons")
                for m in materials
                if m.get("file_url")
            ]
            if paths:
                supabase.storage.from_("lessons").remove(paths)

        # 2️⃣ QUESTIONS → questions bucket (flat)
        quizzes = (
            supabase.table("questions")
            .select("file_url")
            .eq("class_id", class_id)
            .execute()
            .data
        )

        if quizzes:
            paths = [
                extract_storage_path(q["file_url"], "questions")
                for q in quizzes
                if q.get("file_url")
            ]
            if paths:
                supabase.storage.from_("questions").remove(paths)

        # 3️⃣ NOTES → notes bucket (flat)
        notes = (
            supabase.table("notes")
            .select("image_url")
            .eq("class_id", class_id)
            .execute()
            .data
        )

        if notes:
            paths = [
                extract_storage_path(n["image_url"], "notes")
                for n in notes
                if n.get("image_url")
            ]
            if paths:
                supabase.storage.from_("notes").remove(paths)

        # 4️⃣ Delete class (DB cascade removes rows)
        supabase.table("classes") \
            .delete() \
            .eq("id", class_id) \
            .execute()

        return {
            "status": "success",
            "message": "Class, database rows, and storage files deleted"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
