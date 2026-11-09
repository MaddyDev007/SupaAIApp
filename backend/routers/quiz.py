# backend/routers/quiz.py

from fastapi import APIRouter, Depends, HTTPException

from schemas import QuizStorePayload
from security import authenticated_user, ensure_teacher_owns_class, supabase_admin

router = APIRouter()
supabase = supabase_admin


@router.post("/store")
async def store_quiz(
    payload: QuizStorePayload,
    user: dict = Depends(authenticated_user),
):
    # Pydantic has already checked field types, UUIDs, question structure,
    # option count, answer index, field lengths, and unexpected keys.
    if str(payload.teacher_id) != user["id"]:
        raise HTTPException(status_code=403, detail="Teacher identity mismatch")

    class_id = str(payload.class_id)
    material_id = str(payload.material_id)
    pdf_url = str(payload.pdf_url)

    ensure_teacher_owns_class(user["id"], class_id)

    material_response = (
        supabase_admin.table("materials")
        .select("id, class_id, uploaded_by, file_url")
        .eq("id", material_id)
        .eq("class_id", class_id)
        .eq("uploaded_by", user["id"])
        .maybe_single()
        .execute()
    )
    material = getattr(material_response, "data", None)

    if not material or material.get("file_url") != pdf_url:
        raise HTTPException(
            status_code=403,
            detail="PDF does not match your class material",
        )

    data = {
        "created_by": user["id"],
        "class_id": class_id,
        "subject": payload.subject,
        "questions": [question.dict() for question in payload.questions],
        "material_id": material_id,
        "pdf_url": pdf_url,
        "text_preview": payload.text_preview,
    }

    supabase.table("quizzes").insert(data).execute()

    return {"message": "Quiz stored successfully"}
