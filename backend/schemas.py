"""Strict request and AI-output schemas used by the SmartClass API."""

from typing import List
from uuid import UUID

from pydantic import BaseModel, Field, HttpUrl, conint, constr


# Strict strings prevent numbers/booleans from silently becoming text.
SubjectText = constr(strict=True, strip_whitespace=True, min_length=1, max_length=120)
QuestionText = constr(strict=True, strip_whitespace=True, min_length=1, max_length=1000)
OptionText = constr(strict=True, strip_whitespace=True, min_length=1, max_length=300)
PreviewText = constr(strict=True, strip_whitespace=True, min_length=1, max_length=20000)
AnswerIndex = conint(strict=True, ge=0, le=3)


class APIModel(BaseModel):
    """Base model that rejects unknown keys instead of silently ignoring them."""

    class Config:
        extra = "forbid"


class UploadMetadata(APIModel):
    class_id: UUID
    material_id: UUID
    subject: SubjectText
    teacher_id: UUID


class UploadPayload(APIModel):
    pdf_url: HttpUrl
    metadata: UploadMetadata


class QuizQuestion(APIModel):
    question: QuestionText
    options: List[OptionText] = Field(..., min_length=4, max_length=4)
    answer: AnswerIndex


class GeneratedQuizQuestions(APIModel):
    questions: List[QuizQuestion] = Field(..., min_length=1, max_length=100)


class QuizStorePayload(APIModel):
    teacher_id: UUID
    class_id: UUID
    subject: SubjectText
    questions: List[QuizQuestion] = Field(..., min_length=1, max_length=100)
    material_id: UUID
    pdf_url: HttpUrl
    text_preview: PreviewText


class ExamGenerationPayload(APIModel):
    pdf_url: HttpUrl
    metadata: UploadMetadata


class GeneratedExamQuestions(APIModel):
    two_mark: List[QuestionText] = Field(
        ..., alias="2_mark", min_length=1, max_length=10
    )
    thirteen_mark: List[QuestionText] = Field(
        ..., alias="13_mark", min_length=1, max_length=10
    )
