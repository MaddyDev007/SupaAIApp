# backend/routers/quiz.py

from fastapi import APIRouter, Body, HTTPException
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

@router.post("/store")
async def store_quiz(payload: dict = Body(...)):
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
        return {"error": "Missing required fields"}

    data = {
        "created_by": payload["teacher_id"],
        "class_id": payload["class_id"],   # ✅ ADD THIS
        "subject": payload["subject"],
        "questions": payload["questions"],
        "material_id": payload["material_id"],
        "pdf_url": payload["pdf_url"],
        "text_preview": payload["text_preview"],
    }

    supabase.table("quizzes").insert(data).execute()

    return {"message": "Quiz stored successfully"}

