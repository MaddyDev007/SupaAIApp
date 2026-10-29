# backend/routers/quiz.py

from fastapi import APIRouter, Body, HTTPException, Depends
from security import authenticated_user, ensure_teacher_owns_class, supabase_admin
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

@router.post("/store")
async def store_quiz(
    payload: dict = Body(...),
    user: dict = Depends(authenticated_user),
):
    required = [
        "teacher_id",
        "class_id",      # ✅ REQUIRED
        "subject",
        "questions",
        "material_id",
        "pdf_url",
        "text_preview",
    ]

    if not all(k in payload for k in required):
        raise HTTPException(status_code=400, detail="Missing required fields")

    if str(payload["teacher_id"]) != user["id"]:
        raise HTTPException(status_code=403, detail="Teacher identity mismatch")

    ensure_teacher_owns_class(user["id"], str(payload["class_id"]))

    material = (
        supabase_admin.table("materials")
        .select("id, class_id, uploaded_by, file_url")
        .eq("id", str(payload["material_id"]))
        .eq("class_id", str(payload["class_id"]))
        .eq("uploaded_by", user["id"])
        .maybe_single()
        .execute()
    ).data
    if not material or material.get("file_url") != payload["pdf_url"]:
        raise HTTPException(status_code=403, detail="PDF does not match your class material")

    data = {
        "created_by": user["id"],
        "class_id": payload["class_id"],   # ✅ ADD THIS
        "subject": payload["subject"],
        "questions": payload["questions"],
        "material_id": payload["material_id"],
        "pdf_url": payload["pdf_url"],
        "text_preview": payload["text_preview"],
    }

    supabase.table("quizzes").insert(data).execute()

    return {"message": "Quiz stored successfully"}

