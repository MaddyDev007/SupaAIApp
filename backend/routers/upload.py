from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.pdf_extractor import extract_text_from_url
from services.cohere_api import generate_questions

router = APIRouter()

class UploadPayload(BaseModel):
    pdf_url: str
    metadata: dict  # expects class_id, material_id, subject, teacher_id

@router.post("/")
async def handle_upload(payload: UploadPayload):
    pdf_url = payload.pdf_url
    metadata = payload.metadata

    # ✅ Validate required metadata
    required_keys = {"class_id", "material_id", "subject", "teacher_id"}
    if not required_keys.issubset(metadata.keys()):
        raise HTTPException(
            status_code=400,
            detail=f"Missing required metadata fields: {required_keys}"
        )

    if not pdf_url.startswith("http"):
        raise HTTPException(status_code=400, detail="Invalid PDF URL")

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
