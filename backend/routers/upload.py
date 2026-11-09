from fastapi import APIRouter, Depends, HTTPException
from pydantic import ValidationError

from schemas import GeneratedQuizQuestions, UploadPayload
from security import authenticated_user, ensure_teacher_owns_class, supabase_admin
from services.private_storage import storage_path_from_reference
from services.pdf_extractor import extract_text_from_url
from services.gemini_api import generate_questions

router = APIRouter()


@router.post("/")
async def handle_upload(
    payload: UploadPayload,
    user: dict = Depends(authenticated_user),
):
    pdf_url = str(payload.pdf_url)
    metadata = payload.metadata

    # UUID and required-field validation is performed by UploadPayload.
    if str(metadata.teacher_id) != user["id"]:
        raise HTTPException(status_code=403, detail="Teacher identity mismatch")

    class_id = str(metadata.class_id)
    material_id = str(metadata.material_id)
    ensure_teacher_owns_class(user["id"], class_id)

    material_response = (
        supabase_admin.table("materials")
        .select("id, file_url, class_id, uploaded_by")
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
            detail="PDF must belong to your class material",
        )

    # Do not fetch arbitrary URLs. Only accept a reference to this project's
    # private lessons bucket after checking material ownership.
    storage_path_from_reference(pdf_url, "lessons")

    text = extract_text_from_url(pdf_url)
    if not text or not text.strip():
        raise HTTPException(
            status_code=422,
            detail="The PDF contains no extractable text. Upload a readable PDF and try again.",
        )

    text_preview = text[:3000]

    # AI output is untrusted input too. Validate it before returning it to the
    # Flutter client or allowing it to be stored by /quiz/store.
    generated_questions = generate_questions(text)
    try:
        validated_questions = GeneratedQuizQuestions(questions=generated_questions)
    except ValidationError as exc:
        print(
            "[Upload Validation] Gemini returned an invalid quiz structure "
            f"({len(exc.errors())} validation errors)"
        )
        raise HTTPException(
            status_code=502,
            detail="The question generator returned an invalid response. Please retry.",
        ) from exc

    questions = [question.dict() for question in validated_questions.questions]

    return {
        "status": "success",
        "questions": questions,
        "text_preview": text_preview,
        "metadata": {
            "material_id": material_id,
            "class_id": class_id,
            "subject": metadata.subject,
            "teacher_id": str(metadata.teacher_id),
        },
    }
