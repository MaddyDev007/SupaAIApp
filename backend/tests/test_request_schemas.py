"""Unit tests for strict request and AI-output schemas.

Run from the backend directory:
    python -m unittest discover -s tests -v
"""

import unittest

from pydantic import ValidationError

from schemas import (
    ExamGenerationPayload,
    GeneratedExamQuestions,
    GeneratedQuizQuestions,
    QuizStorePayload,
    UploadPayload,
)


class RequestSchemaTests(unittest.TestCase):
    def setUp(self):
        self.class_id = "11111111-1111-4111-8111-111111111111"
        self.material_id = "22222222-2222-4222-8222-222222222222"
        self.teacher_id = "33333333-3333-4333-8333-333333333333"
        self.pdf_url = (
            "https://example.supabase.co/storage/v1/object/public/"
            "lessons/materials/class/file.pdf"
        )
        self.metadata = {
            "class_id": self.class_id,
            "material_id": self.material_id,
            "subject": "Mathematics",
            "teacher_id": self.teacher_id,
        }
        self.question = {
            "question": "What is 2 + 2?",
            "options": ["1", "2", "3", "4"],
            "answer": 3,
        }

    def test_upload_payload_accepts_current_flutter_shape(self):
        payload = UploadPayload(
            pdf_url=self.pdf_url,
            metadata=self.metadata,
        )
        self.assertEqual(str(payload.metadata.class_id), self.class_id)

    def test_exam_payload_accepts_current_flutter_shape(self):
        payload = ExamGenerationPayload(
            pdf_url=self.pdf_url,
            metadata=self.metadata,
        )
        self.assertEqual(payload.metadata.subject, "Mathematics")

    def test_missing_metadata_field_is_rejected(self):
        metadata = dict(self.metadata)
        metadata.pop("material_id")
        with self.assertRaises(ValidationError):
            UploadPayload(pdf_url=self.pdf_url, metadata=metadata)

    def test_invalid_uuid_is_rejected(self):
        metadata = dict(self.metadata)
        metadata["class_id"] = "not-a-uuid"
        with self.assertRaises(ValidationError):
            UploadPayload(pdf_url=self.pdf_url, metadata=metadata)

    def test_unknown_metadata_field_is_rejected(self):
        metadata = {**self.metadata, "unexpected": "value"}
        with self.assertRaises(ValidationError):
            UploadPayload(pdf_url=self.pdf_url, metadata=metadata)

    def test_quiz_payload_accepts_expected_question_shape(self):
        payload = QuizStorePayload(
            teacher_id=self.teacher_id,
            class_id=self.class_id,
            subject="Mathematics",
            questions=[self.question],
            material_id=self.material_id,
            pdf_url=self.pdf_url,
            text_preview="A short preview of the uploaded material.",
        )
        self.assertEqual(payload.questions[0].answer, 3)

    def test_quiz_rejects_wrong_number_of_options(self):
        question = {**self.question, "options": ["A", "B", "C"]}
        with self.assertRaises(ValidationError):
            GeneratedQuizQuestions(questions=[question])

    def test_quiz_rejects_string_answer_index(self):
        question = {**self.question, "answer": "3"}
        with self.assertRaises(ValidationError):
            GeneratedQuizQuestions(questions=[question])

    def test_quiz_rejects_empty_question_list(self):
        with self.assertRaises(ValidationError):
            GeneratedQuizQuestions(questions=[])

    def test_exam_output_requires_both_sections(self):
        with self.assertRaises(ValidationError):
            GeneratedExamQuestions(**{"2_mark": ["Question 1"]})

    def test_exam_output_accepts_expected_sections(self):
        payload = GeneratedExamQuestions(
            **{
                "2_mark": ["Short question"],
                "13_mark": ["Long question"],
            }
        )
        self.assertEqual(payload.two_mark, ["Short question"])
        self.assertEqual(payload.thirteen_mark, ["Long question"])


if __name__ == "__main__":
    unittest.main()
