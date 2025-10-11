from fastapi import APIRouter, Body
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
    if not all(k in payload for k in ["teacher_id", "department", "year", "subject", "questions", "pdf_url", "text_preview"]):
        return {"error": "Missing required fields"}

    data = {
        "created_by": payload["teacher_id"],
        "department": payload["department"],
        "year": payload["year"],
        "subject": payload["subject"],
        "questions": payload["questions"],
        "pdf_url": payload["pdf_url"],
        "text_preview": payload["text_preview"], 
    }
    supabase.table("quizzes").insert(data).execute()
    return {"message": "Quiz stored successfully"}
