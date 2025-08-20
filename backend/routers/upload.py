from fastapi import APIRouter, HTTPException, Body
from pydantic import BaseModel
from services.pdf_extractor import extract_text_from_url
from services.cohere_api import generate_questions

router = APIRouter()

class UploadPayload(BaseModel):
    pdf_url: str
    metadata: dict

@router.post("/")
async def handle_upload(payload: UploadPayload):
    pdf_url = payload.pdf_url
    metadata = payload.metadata

    if not pdf_url.startswith("http"):
        raise HTTPException(status_code=400, detail="Invalid PDF URL")

    text = extract_text_from_url(pdf_url)
    print(f"Extracted text length: {len(text)} characters")
    if not text.strip():
        raise HTTPException(status_code=500, detail="Text extraction failed or empty content")
    try:
        questions = generate_questions(text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Question generation failed: {e}")
    print(f"Generated questions: {questions}")
    return {
        "status": "success",
        "questions": questions,
        "metadata": metadata
    }
