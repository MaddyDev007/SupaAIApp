import json
import os
import re
import io
import asyncio
import httpx
import pdfplumber
from dotenv import load_dotenv
from pathlib import Path
from cohere import Client
from fastapi import HTTPException
from supabase import create_client

# -------------------------------------------------------------------
# 🔧 Load environment variables
# -------------------------------------------------------------------
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

COHERE_KEY = os.getenv("COHERE_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

co = Client(COHERE_KEY)
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# -------------------------------------------------------------------
# 🧩 Utility: Split long text into chunks
# -------------------------------------------------------------------
def chunk_text(text: str, size: int = 2000):
    return [text[i:i + size] for i in range(0, len(text), size)]

# -------------------------------------------------------------------
# 🧠 Generate MCQs from text
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

Only return a valid JSON array.
No explanations. No markdown.

Content:
{text}
"""

    try:
        response = co.chat(
            model="command-a-03-2025",
            message=prompt,
            temperature=0.3,
        )

        raw = response.text.strip()

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            match = re.search(r'\[\s*{.*}\s*]', raw, re.DOTALL)
            if match:
                return json.loads(match.group())
            raise HTTPException(
                status_code=500,
                detail="Malformed JSON returned by Cohere"
            )

    except Exception as e:
        print(f"[Cohere MCQ Error] {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate MCQs"
        )

# -------------------------------------------------------------------
# 🧩 Generate MCQs for full document (chunked)
# -------------------------------------------------------------------
def generate_all_questions(full_text: str):
    chunks = chunk_text(full_text)
    all_questions = []

    for i, chunk in enumerate(chunks, start=1):
        print(f"⚙️ Processing chunk {i}/{len(chunks)}")
        all_questions.extend(generate_questions(chunk))

    return all_questions

# -------------------------------------------------------------------
# 📄 Extract text from PDF bytes
# -------------------------------------------------------------------
def extract_text(file_bytes: bytes) -> str:
    try:
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            return "\n".join(page.extract_text() or "" for page in pdf.pages)
    except Exception as e:
        print(f"[PDF Extraction Error] {e}")
        return ""

# -------------------------------------------------------------------
# 🔍 Fetch relevant documents (CLASS-SCOPED)
# -------------------------------------------------------------------
async def fetch_relevant_documents(
    question: str,
    class_id: str,
    top_k: int = 2
):
    try:
        # ✅ ONLY quizzes from this class
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

        for r in records:
            preview = r.get("text_preview", "")
            overlap = len(question_words & set(preview.lower().split()))
            scored.append((r, overlap))

        # Pick top matching PDFs
        scored.sort(key=lambda x: x[1], reverse=True)
        top_docs = [d for d, s in scored[:top_k] if s > 0]

        documents = []
        async with httpx.AsyncClient(timeout=60.0) as client:
            for d in top_docs:
                response = await client.get(d["pdf_url"])
                text = await asyncio.to_thread(
                    extract_text,
                    response.content
                )
                documents.append({
                    "title": d["pdf_url"].split("/")[-1],
                    "text": text,
                })

        return documents

    except Exception as e:
        print(f"[Document Fetch Error] {e}")
        return []

# -------------------------------------------------------------------
# 💬 Chatbot (CLASS-SCOPED CONTEXT)
# -------------------------------------------------------------------
# NOTE: Still global memory (acceptable for now)
chat_history = []

async def ask_chatbot(question: str, class_id: str):
    global chat_history

    try:
        documents = await fetch_relevant_documents(
            question=question,
            class_id=class_id,
        )

        # Keep history bounded
        if len(chat_history) > 20:
            chat_history = chat_history[-20:]

        chat_history.append({
            "role": "USER",
            "message": question
        })

        def run_cohere():
            return co.chat(
                model="command-a-03-2025",
                message=question,
                chat_history=chat_history,
                documents=documents,
            ).text

        answer = await asyncio.to_thread(run_cohere)

        chat_history.append({
            "role": "CHATBOT",
            "message": answer
        })

        return answer

    except Exception as e:
        print(f"[Chatbot Error] {e}")
        raise HTTPException(
            status_code=500,
            detail="Chatbot failed to respond"
        )

# -------------------------------------------------------------------
# 🧾 Generate Exam Questions
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
        response = co.chat(
            model="command-a-03-2025",
            message=prompt,
            temperature=0.3,
        )

        raw = response.text.strip()

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            start, end = raw.find("{"), raw.rfind("}")
            if start == -1 or end == -1:
                raise HTTPException(
                    status_code=500,
                    detail="Malformed JSON from Cohere"
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
            detail="Failed to generate exam questions"
        )
