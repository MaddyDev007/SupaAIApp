from fastapi import APIRouter, HTTPException
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

# 🔐 Service role client
supabase = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
)

@router.delete("/class")
def delete_class(class_id: str):
    try:
        # 1️⃣ MATERIALS → lessons bucket
        materials = supabase.table("materials") \
            .select("file_path") \
            .eq("class_id", class_id) \
            .execute().data

        if materials:
            supabase.storage.from_("lessons") \
                .remove([m["file_path"] for m in materials])

        # 2️⃣ QUIZZES → questions bucket (FLAT)
        quizzes = supabase.table("quizzes") \
            .select("file_path") \
            .eq("class_id", class_id) \
            .execute().data

        if quizzes:
            supabase.storage.from_("questions") \
                .remove([q["file_path"] for q in quizzes])

        # 3️⃣ NOTES → notes bucket (FLAT)
        notes = supabase.table("notes") \
            .select("file_path") \
            .eq("class_id", class_id) \
            .execute().data

        if notes:
            supabase.storage.from_("notes") \
                .remove([n["file_path"] for n in notes])

        # 4️⃣ Delete class (DB cascade removes rows)
        supabase.table("classes") \
            .delete() \
            .eq("id", class_id) \
            .execute()

        return {
            "status": "success",
            "message": "Class and all related files deleted"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
