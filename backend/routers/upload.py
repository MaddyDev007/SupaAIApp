from fastapi import APIRouter, HTTPException, Depends
from security import authenticated_user, ensure_teacher_owns_class, supabase_admin
from services.private_storage import storage_path_from_reference
from pydantic import BaseModel
from services.pdf_extractor import extract_text_from_url
from services.gemini_api import generate_questions
# from services.cohere_api import generate_questions

router = APIRouter()

class UploadPayload(BaseModel):
    pdf_url: str
    metadata: dict  # expects class_id, material_id, subject, teacher_id

@router.post("/")
async def handle_upload(
    payload: UploadPayload,
    user: dict = Depends(authenticated_user),
):
    pdf_url = payload.pdf_url
    metadata = payload.metadata

    # ✅ Validate required metadata
    required_keys = {"class_id", "material_id", "subject", "teacher_id"}
    if not required_keys.issubset(metadata.keys()):
        raise HTTPException(
            status_code=400,
            detail=f"Missing required metadata fields: {required_keys}"
        )

    if str(metadata["teacher_id"]) != user["id"]:
        raise HTTPException(status_code=403, detail="Teacher identity mismatch")

    ensure_teacher_owns_class(user["id"], str(metadata["class_id"]))

    material = (
        supabase_admin.table("materials")
        .select("id, file_url, class_id, uploaded_by")
        .eq("id", str(metadata["material_id"]))
        .eq("class_id", str(metadata["class_id"]))
        .eq("uploaded_by", user["id"])
        .maybe_single()
        .execute()
    ).data
    if not material or material.get("file_url") != pdf_url:
        raise HTTPException(status_code=403, detail="PDF must belong to your class material")

    # Ensure the URL resolves to this project's Supabase storage object rather
    # than allowing arbitrary external URLs (SSRF / private-file bypass).
    storage_path_from_reference(pdf_url, "lessons")

    # 1️⃣ Extract text
    text = extract_text_from_url(pdf_url)
    if not text.strip():
        raise HTTPException(
            status_code=500,
            detail="Text extraction failed or empty content"
        )

    # 2️⃣ Create preview
    text_preview = text[:3000]

    # 3️⃣ Generate MCQs
    try:
        questions = generate_questions(text)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Question generation failed: {e}"
        )

    return {
        "status": "success",
        "questions": questions,
        "text_preview": text_preview,
        "metadata": metadata,  # ✅ now contains class_id
    }
