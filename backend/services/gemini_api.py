import asyncio
import io
import json
import os
import re
from pathlib import Path

import google.generativeai as genai
import httpx
import pdfplumber
from dotenv import load_dotenv
from fastapi import HTTPException
from fastapi.responses import StreamingResponse
from supabase import create_client

# -------------------------------------------------------------------
# Load environment variables
# -------------------------------------------------------------------
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

GEMINI_KEY = os.getenv("GEMINI_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

genai.configure(api_key=GEMINI_KEY)

# Gemini models
MCQ_MODEL = genai.GenerativeModel("models/gemini-2.5-flash")
CHAT_MODEL = genai.GenerativeModel("models/gemini-2.5-flash")
EXAM_MODEL = genai.GenerativeModel("models/gemini-2.5-flash")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

DOCUMENT_CACHE = {}
MARKDOWN_CACHE = {}
PROJECT_ROOT = Path(__file__).resolve().parents[2]
GLOBAL_CONTEXT_FILES = {
    "GUIDE": [
        PROJECT_ROOT / "smartclass" / "guide.md",
        PROJECT_ROOT / "guide.md",
    ],
    "API": [
        PROJECT_ROOT / "API.md",
        PROJECT_ROOT / "smartclass" / "API.md",
    ],
    "README": [
        PROJECT_ROOT / "README.md",
        PROJECT_ROOT / "smartclass" / "README.md",
    ],
}
CHATBOT_SYSTEM_PROMPT = (
    "Use GUIDE for how-to, API for backend, README for general, "
    "CLASS MATERIAL for study."
)


# -------------------------------------------------------------------
# Utility: Split long text into chunks
# -------------------------------------------------------------------
def chunk_text(text: str, size: int = 2000):
    return [text[i:i + size] for i in range(0, len(text), size)]


# -------------------------------------------------------------------
# Generate MCQs from text
# -------------------------------------------------------------------
def generate_questions(text: str):
    prompt = f"""
You are a question generator.
Return exactly 10 multiple choice questions in JSON.

Each item must be:
{{
  "question": "...",
  "options": ["A", "B", "C", "D"],
  "answer": 0
}}

Only return a valid JSON array - no text, no formatting, no explanations, no markdown.

Content:
{text}
"""

    try:
        response = MCQ_MODEL.generate_content(
            prompt,
            generation_config={"temperature": 0.3},
        )

        raw = response.text.strip()

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            match = re.search(r"\[\s*{.*}\s*]", raw, re.DOTALL)
            if match:
                return json.loads(match.group())
            raise HTTPException(
                status_code=500,
                detail="Malformed JSON returned by Gemini",
            )

    except Exception as e:
        print(f"[Gemini MCQ Error] {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate MCQs",
        )


# -------------------------------------------------------------------
# Generate MCQs for full document (chunked)
# -------------------------------------------------------------------
def generate_all_questions(full_text: str):
    chunks = chunk_text(full_text)
    all_questions = []

    for i, chunk in enumerate(chunks, start=1):
        print(f"Processing chunk {i}/{len(chunks)}")
        all_questions.extend(generate_questions(chunk))

    return all_questions


# -------------------------------------------------------------------
# Extract text from PDF bytes
# -------------------------------------------------------------------
def extract_text(file_bytes: bytes) -> str:
    try:
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            return "\n".join(page.extract_text() or "" for page in pdf.pages)
    except Exception as e:
        print(f"[PDF Extraction Error] {e}")
        return ""


# -------------------------------------------------------------------
# Fetch relevant documents (CLASS-SCOPED)
# -------------------------------------------------------------------
async def fetch_relevant_documents(
    question: str,
    class_id: str,
    top_k: int = 2,
):
    try:
        res = (
            supabase
            .table("quizzes")
            .select("pdf_url, text_preview")
            .eq("class_id", class_id)
            .execute()
        )

        records = res.data or []
        if not records:
            return []

        question_words = set(question.lower().split())
        scored = []

        for record in records:
            preview = record.get("text_preview", "")
            overlap = len(question_words & set(preview.lower().split()))
            scored.append((record, overlap))

        scored.sort(key=lambda item: item[1], reverse=True)
        top_docs = [doc for doc, score in scored[:top_k] if score > 0]

        documents = []
        async with httpx.AsyncClient(timeout=60.0) as client:
            for doc in top_docs:
                pdf_url = doc["pdf_url"]
                cache_key = f"{class_id}:{pdf_url}"

                if cache_key in DOCUMENT_CACHE:
                    text = DOCUMENT_CACHE[cache_key]
                else:
                    response = await client.get(pdf_url)
                    text = await asyncio.to_thread(
                        extract_text,
                        response.content,
                    )
                    DOCUMENT_CACHE[cache_key] = text

                    if len(DOCUMENT_CACHE) > 100:
                        DOCUMENT_CACHE.clear()

                documents.append({
                    "title": pdf_url.split("/")[-1],
                    "text": text,
                })

        return documents

    except Exception as e:
        print(f"[Document Fetch Error] {e}")
        return []


# -------------------------------------------------------------------
# Multi-context routing helpers
# -------------------------------------------------------------------
def detect_chat_intent(question: str) -> str:
    normalized = (question or "").strip().lower()

    if any(keyword in normalized for keyword in ("api", "endpoint")):
        return "API"

    if any(
        keyword in normalized
        for keyword in ("what is smartclass", "features")
    ):
        return "README"

    if any(
        keyword in normalized
        for keyword in ("how", "steps", "upload", "quiz")
    ):
        return "GUIDE"

    return "STUDY"


def load_local_markdown(intent: str) -> str:
    cache_key = intent.upper()

    if cache_key in MARKDOWN_CACHE:
        return MARKDOWN_CACHE[cache_key]

    for path in GLOBAL_CONTEXT_FILES.get(cache_key, []):
        if path.exists():
            content = path.read_text(encoding="utf-8")
            MARKDOWN_CACHE[cache_key] = content
            return content

    return ""


def build_routing_context_block(intent: str, context_text: str) -> str:
    context_label_map = {
        "GUIDE": "GUIDE",
        "API": "API",
        "README": "README",
        "STUDY": "CLASS MATERIAL",
    }
    context_label = context_label_map.get(intent, "CLASS MATERIAL")
    return (
        f"Use the following {context_label} context to answer the user.\n\n"
        f"{context_text}"
    )


# -------------------------------------------------------------------
# Chatbot (multi-context + class-scoped study retrieval)
# -------------------------------------------------------------------
chat_history = []


async def ask_chatbot_stream(question: str, class_id: str):
    global chat_history

    try:
        intent = detect_chat_intent(question)
        context_text = ""

        if intent in {"GUIDE", "API", "README"}:
            context_text = load_local_markdown(intent)
        else:
            documents = await fetch_relevant_documents(
                question=question,
                class_id=class_id,
            )
            if documents:
                context_text = "\n\n".join(
                    f"{document['title']}:\n{document['text']}"
                    for document in documents
                )

        if len(chat_history) > 20:
            chat_history = chat_history[-20:]

        messages = [{
            "role": "user",
            "parts": [{"text": CHATBOT_SYSTEM_PROMPT}],
        }]

        if context_text:
            messages.append({
                "role": "user",
                "parts": [{
                    "text": build_routing_context_block(intent, context_text)
                }],
            })

        for msg in chat_history:
            role = "user" if msg["role"] == "USER" else "model"
            messages.append({
                "role": role,
                "parts": [{"text": msg["message"]}],
            })

        messages.append({
            "role": "user",
            "parts": [{"text": question}],
        })

        response = CHAT_MODEL.generate_content(
            messages,
            stream=True,
        )

        async def stream_generator():
            full_answer = ""

            for chunk in response:
                if chunk.text:
                    full_answer += chunk.text
                    yield chunk.text

            chat_history.append({"role": "USER", "message": question})
            chat_history.append({"role": "CHATBOT", "message": full_answer})

        return StreamingResponse(
            stream_generator(),
            media_type="text/plain",
        )

    except Exception as e:
        print(f"[Chatbot Stream Error] {e}")
        raise HTTPException(
            status_code=500,
            detail="Chatbot failed to respond",
        )


# -------------------------------------------------------------------
# Generate Exam Questions
# -------------------------------------------------------------------
def generate_exam_questions(text: str):
    prompt = f"""
You are an exam question generator.

Generate:
- 5 short 2-mark questions
- 2 long 13-mark questions

Study Material:
{text}

Return ONLY valid JSON:
{{
  "2_mark": ["Q1", "Q2", "Q3", "Q4", "Q5"],
  "13_mark": ["Q1", "Q2"]
}}
"""

    try:
        response = EXAM_MODEL.generate_content(
            prompt,
            generation_config={"temperature": 0.3},
        )

        raw = response.text.strip()

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            start, end = raw.find("{"), raw.rfind("}")
            if start == -1 or end == -1:
                raise HTTPException(
                    status_code=500,
                    detail="Malformed JSON from Gemini",
                )
            data = json.loads(raw[start:end + 1])

        return {
            "2_mark": data.get("2_mark", []),
            "13_mark": data.get("13_mark", []),
        }

    except Exception as e:
        print(f"[Exam Generation Error] {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate exam questions",
        )
