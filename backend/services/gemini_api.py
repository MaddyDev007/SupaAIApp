import asyncio
import io
import json
import re
from pathlib import Path

import google.generativeai as genai
import httpx
import pdfplumber
from fastapi import HTTPException
from fastapi.responses import StreamingResponse

from config import get_settings
from security import supabase_admin
from services.private_storage import download_private_file

# -------------------------------------------------------------------
# Validated application configuration
# -------------------------------------------------------------------
settings = get_settings()
GEMINI_KEY = settings.gemini_api_key

genai.configure(api_key=GEMINI_KEY)

# Gemini models
MCQ_MODEL = genai.GenerativeModel("models/gemini-2.5-flash")
CHAT_MODEL = genai.GenerativeModel("models/gemini-2.5-flash")
EXAM_MODEL = genai.GenerativeModel("models/gemini-2.5-flash")

supabase = supabase_admin

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
        print(f"[Gemini MCQ Error] {type(e).__name__}: {e}")
        raise HTTPException(
            status_code=502,
            detail="The question generator failed or returned invalid JSON. Please retry.",
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
        for doc in top_docs:
            pdf_reference = doc["pdf_url"]
            cache_key = f"{class_id}:{pdf_reference}"

            if cache_key in DOCUMENT_CACHE:
                text = DOCUMENT_CACHE[cache_key]
            else:
                file_bytes = await asyncio.to_thread(
                    download_private_file,
                    pdf_reference,
                    "lessons",
                )
                text = await asyncio.to_thread(extract_text, file_bytes)
                DOCUMENT_CACHE[cache_key] = text

                if len(DOCUMENT_CACHE) > 100:
                    DOCUMENT_CACHE.clear()

            documents.append({
                "title": pdf_reference.split("/")[-1],
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
async def ask_chatbot_stream(
    question: str,
    class_id: str,
    history: list[dict] | None = None,
    on_answer_complete=None,
):
    """Stream a reply using only the supplied user's saved conversation history."""
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

        # The caller loads history from the persistent session belonging to
        # the authenticated user and class. Never use process-global history.
        for msg in (history or []):
            stored_role = msg.get("role")
            content = msg.get("content", "")
            if not content:
                continue
            if stored_role not in {"user", "assistant"}:
                continue
            messages.append({
                "role": "user" if stored_role == "user" else "model",
                "parts": [{"text": content}],
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
                chunk_text = getattr(chunk, "text", None)
                if chunk_text:
                    full_answer += chunk_text
                    yield chunk_text

            # Persist only a completed assistant response. User prompt was
            # stored by the authenticated router before streaming started.
            if full_answer and on_answer_complete is not None:
                try:
                    await on_answer_complete(full_answer)
                except Exception as persist_error:
                    print(f"[Chat History Persistence Error] {persist_error}")

        return StreamingResponse(
            stream_generator(),
            media_type="text/plain",
        )

    except HTTPException:
        raise
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
            # Return the raw parsed structure. The API route validates the
            # required sections and their contents before using the output.
            return json.loads(raw)
        except json.JSONDecodeError:
            start_index, end_index = raw.find("{"), raw.rfind("}")
            if start_index == -1 or end_index == -1:
                raise ValueError("Gemini did not return a JSON object")
            return json.loads(raw[start_index:end_index + 1])

    except Exception as exc:
        print(f"[Exam Generation Error] {type(exc).__name__}: {exc}")
        raise HTTPException(
            status_code=502,
            detail="The exam generator failed or returned invalid JSON. Please retry.",
        ) from exc
