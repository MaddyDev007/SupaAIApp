# backend/routers/question.py

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import requests, pdfplumber, io, os, uuid
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from supabase import create_client
from services.cohere_api import generate_exam_questions
from dotenv import load_dotenv

load_dotenv()
router = APIRouter()

# Supabase client
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


# ---- Request schema ----
class ExamRequest(BaseModel):
    pdf_url: str
    metadata: dict  # expects class_id, subject, teacher_id, material_id


@router.post("/generate-exam")
async def generate_exam(req: ExamRequest):
    try:
        metadata = req.metadata

        required = {"class_id", "subject", "teacher_id", "material_id"}
        if not required.issubset(metadata.keys()):
            raise HTTPException(
                status_code=400,
                detail=f"Missing required metadata: {required}"
            )

        subject = metadata["subject"]
        class_id = metadata["class_id"]

        # 🔹 Download uploaded PDF
        response = requests.get(req.pdf_url)
        if response.status_code != 200:
            raise HTTPException(
                status_code=400,
                detail="Failed to fetch PDF"
            )

        # 🔹 Extract text
        with pdfplumber.open(io.BytesIO(response.content)) as pdf:
            text = "\n".join(page.extract_text() or "" for page in pdf.pages)

        if not text.strip():
            raise HTTPException(
                status_code=400,
                detail="No text extracted from PDF"
            )

        # 🔹 Generate exam questions
        questions = generate_exam_questions(text)

        # 🔹 Create exam PDF in memory
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer)
        styles = getSampleStyleSheet()

        content = [
            Paragraph(f"Exam Question Paper - {subject}", styles["Heading1"]),
            Spacer(1, 20),
            Paragraph("Section A - 2 Marks", styles["Heading2"]),
        ]

        for i, q in enumerate(questions.get("2_mark", []), 1):
            content.append(Paragraph(f"{i}. {q}", styles["Normal"]))
            content.append(Spacer(1, 8))

        content.append(Spacer(1, 20))
        content.append(Paragraph("Section B - 13 Marks", styles["Heading2"]))

        for i, q in enumerate(questions.get("13_mark", []), 1):
            content.append(Paragraph(f"{i}. {q}", styles["Normal"]))
            content.append(Spacer(1, 12))

        doc.build(content)

        # 🔹 Upload exam PDF to Supabase
        buffer.seek(0)
        file_name = f"exam_{uuid.uuid4()}.pdf"

        bucket = supabase.storage.from_("questions")
        bucket.upload(
            file_name,
            buffer.getvalue(),
            {"content-type": "application/pdf"}
        )

        file_url = bucket.get_public_url(file_name)

        # 🔹 Store metadata in DB (CLASS-BASED)
        supabase.table("questions").insert({
    "subject": subject,
    "file_url": file_url,
    "teacher_id": req.metadata.get("teacher_id"),
    "material_id": req.metadata.get("material_id"),
    "class_id": req.metadata.get("class_id"),  # ✅ ADD THIS
    "created_at": "now()",
}).execute()

        return {
            "message": "✅ Exam generated successfully",
            "questions": questions,
            "file_url": file_url,
        }

    except Exception as e:
        print(f"[Exam Generation Error] {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate exam questions"
        )
