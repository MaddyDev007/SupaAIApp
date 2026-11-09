# backend/routers/question.py

import io
import uuid
from xml.sax.saxutils import escape

import pdfplumber
from fastapi import APIRouter, Depends, HTTPException
from pydantic import ValidationError
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

from schemas import ExamGenerationPayload, GeneratedExamQuestions
from security import authenticated_user, ensure_teacher_owns_class, supabase_admin
from services.private_storage import download_private_file, storage_path_from_reference
from services.gemini_api import generate_exam_questions

router = APIRouter()
supabase = supabase_admin


@router.post("/generate-exam")
async def generate_exam(
    req: ExamGenerationPayload,
    user: dict = Depends(authenticated_user),
):
    try:
        metadata = req.metadata
        pdf_url = str(req.pdf_url)
        subject = metadata.subject
        class_id = str(metadata.class_id)
        material_id = str(metadata.material_id)

        if str(metadata.teacher_id) != user["id"]:
            raise HTTPException(status_code=403, detail="Teacher identity mismatch")

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

        storage_path_from_reference(pdf_url, "lessons")
        pdf_bytes = download_private_file(pdf_url, "lessons")

        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            text = "\n".join(page.extract_text() or "" for page in pdf.pages)

        if not text.strip():
            raise HTTPException(
                status_code=422,
                detail="The PDF contains no extractable text. Upload a readable PDF and try again.",
            )

        generated_questions = generate_exam_questions(text)
        try:
            validated_questions = GeneratedExamQuestions(**generated_questions)
        except (ValidationError, TypeError) as exc:
            error_count = len(exc.errors()) if isinstance(exc, ValidationError) else 1
            print(
                "[Exam Validation] Gemini returned an invalid exam structure "
                f"({error_count} validation errors)"
            )
            raise HTTPException(
                status_code=502,
                detail="The exam generator returned an invalid response. Please retry.",
            ) from exc

        questions = {
            "2_mark": validated_questions.two_mark,
            "13_mark": validated_questions.thirteen_mark,
        }

        # Build a PDF using escaped text so generated content is treated as
        # text, not ReportLab paragraph markup.
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer)
        styles = getSampleStyleSheet()

        content = [
            Paragraph(f"Exam Question Paper - {escape(subject)}", styles["Heading1"]),
            Spacer(1, 20),
            Paragraph("Section A - 2 Marks", styles["Heading2"]),
        ]

        for index, question_text in enumerate(questions["2_mark"], 1):
            content.append(
                Paragraph(f"{index}. {escape(question_text)}", styles["Normal"])
            )
            content.append(Spacer(1, 8))

        content.append(Spacer(1, 20))
        content.append(Paragraph("Section B - 13 Marks", styles["Heading2"]))

        for index, question_text in enumerate(questions["13_mark"], 1):
            content.append(
                Paragraph(f"{index}. {escape(question_text)}", styles["Normal"])
            )
            content.append(Spacer(1, 12))

        doc.build(content)

        buffer.seek(0)
        file_name = f"exam_{uuid.uuid4()}.pdf"
        bucket = supabase.storage.from_("questions")
        bucket.upload(
            file_name,
            buffer.getvalue(),
            {"content-type": "application/pdf"},
        )

        file_url = bucket.get_public_url(file_name)

        supabase.table("questions").insert(
            {
                "subject": subject,
                "file_url": file_url,
                "teacher_id": str(metadata.teacher_id),
                "material_id": material_id,
                "class_id": class_id,
                "created_at": "now()",
            }
        ).execute()

        return {
            "message": "Exam generated successfully",
            "questions": questions,
            "file_url": file_url,
        }

    except HTTPException:
        raise
    except Exception as exc:
        print(f"[Exam Generation Error] {type(exc).__name__}: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate exam questions",
        ) from exc
