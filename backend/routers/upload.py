from fastapi import APIRouter, HTTPException
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

    # 1️⃣ Extract full text from PDF
    text = extract_text_from_url(pdf_url)
    print(f"Extracted text length: {len(text)} characters")

    if not text.strip():
        raise HTTPException(status_code=500, detail="Text extraction failed or empty content")

    # 2️⃣ Save a preview of the text (first 2000–3000 chars) to Supabase
    try:
        print("Saving text preview to Supabase...")
        text_preview = text[:3000]
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save preview: {e}")

    # 3️⃣ Generate MCQs from full text
    try:
        questions = generate_questions(text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Question generation failed: {e}")

    # print(f"Generated questions: {text_preview}")

    return {
        "status": "success",
        "questions": questions,
        "text_preview": text_preview, 
        "metadata": metadata,
    }
