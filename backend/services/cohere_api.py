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
# 🧩 Utility: Split long text into chunks (default 2000 chars)
# -------------------------------------------------------------------
def chunk_text(text: str, size: int = 2000):
    return [text[i:i + size] for i in range(0, len(text), size)]

# -------------------------------------------------------------------
# 🧠 Generate MCQs from text (for each chunk)
# -------------------------------------------------------------------
def generate_questions(text: str):
    prompt = f"""
You are a question generator. Return exactly 10 multiple choice questions in JSON.

Each item must be:
{{
  "question": "...",
  "options": ["A", "B", "C", "D"],
  "answer": 0
}}

Only return a valid JSON array — no text, no formatting, no explanations.

Content:
{text}
"""

    try:
        response = co.chat(message=prompt, model="command-a-03-2025", temperature=0.3)
        raw = response.text.strip()
        # print("🧾 Cohere raw output:\n", raw)

        try:
            return json.loads(raw)
        except:
            match = re.search(r'\[\s*{.*}\s*]', raw, re.DOTALL)
            if match:
                return json.loads(match.group())
            raise HTTPException(status_code=500, detail="Malformed JSON from Cohere")

    except Exception as e:
        print(f"[Cohere Error] {e}")
        raise HTTPException(status_code=500, detail="Failed to generate structured questions")

# -------------------------------------------------------------------
# 🧩 Generate questions for the ENTIRE document (merged)
# -------------------------------------------------------------------
def generate_all_questions(full_text: str):
    chunks = chunk_text(full_text)
    all_questions = []

    for i, chunk in enumerate(chunks, start=1):
        print(f"⚙️ Processing chunk {i}/{len(chunks)}...")
        questions = generate_questions(chunk)
        all_questions.extend(questions)

    return all_questions

# -------------------------------------------------------------------
# 📄 Fetch and extract text from all Supabase PDFs
# -------------------------------------------------------------------
def extract_text(file_bytes: bytes):
    try:
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            full_text = "\n".join(page.extract_text() or "" for page in pdf.pages)
        return full_text
    except Exception as e:
        print(f"[PDF Extraction Error] {e}")
        return ""

# -------------------------------------------------------------------
# 💬 Ask chatbot (contextual QA using all documents)
# -------------------------------------------------------------------
# ---------------------------------------
# Fetch only relevant PDFs using keyword matching
# ---------------------------------------
async def fetch_relevant_documents(question: str, top_k: int = 2):
    try:
        # Get all previews from Supabase
        res = supabase.table("quizzes").select("id, pdf_url, text_preview").execute()
        data = res.data
        if not data:
            return []

        question_words = set(question.lower().split())
        scores = []

        # Score each PDF based on keyword overlap
        for d in data:
            preview = d.get("text_preview") or ""  # fallback to empty string
            preview_words = set(preview.lower().split())
            score = len(question_words & preview_words)
            scores.append((d, score))


        # Pick top matching PDFs
        scores.sort(key=lambda x: x[1], reverse=True)
        top_docs = [s[0] for s in scores[:top_k] if s[1] > 0]  # ignore zero matches

        # Download & extract full text
        docs = []
        async with httpx.AsyncClient(timeout=60.0) as client:
            for d in top_docs:
                r = await client.get(d["pdf_url"])
                content = r.content
                text = await asyncio.to_thread(lambda: extract_text(content))
                docs.append({"title": d["pdf_url"].split("/")[-1], "text": text})

        return docs

    except Exception as e:
        print(f"[Material Fetch Error] {e}")
        return []

# ---------------------------------------
# Ask chatbot using only relevant PDFs
# ---------------------------------------
chat_history = []   

# Global or per-user session

async def ask_chatbot(question: str):
    global chat_history
    try:
        documents = await fetch_relevant_documents(question, top_k=2)
        if len(chat_history) > 20:  
            chat_history = chat_history[-20:]

        # ✅ Add new user message to history
        chat_history.append({"role": "USER", "message": question})

        def run_cohere():
            return co.chat(
                model="command-a-03-2025",
                message=question,
                chat_history=chat_history,    # ✅ ← This gives full memory
                documents=documents,
            ).text

        answer = await asyncio.to_thread(run_cohere)

        # ✅ Add bot reply to history
        chat_history.append({"role": "CHATBOT", "message": answer})

        return answer

    except Exception as e:
        print(f"[Chatbot Error] {e}")
        raise HTTPException(status_code=500, detail="Chatbot failed to respond.")

# -------------------------------------------------------------------
# 🧾 Generate Exam Questions (covers full text)
# -------------------------------------------------------------------
def generate_exam_questions(text: str):
    # Merge entire text into one prompt
    prompt = f"""
You are an exam question generator.
Based on the following study material, generate:
- 5 short 2-mark questions (one or two sentences, direct answers).
- 2 long 13-mark questions (essay type, analytical, detailed).

Study Material:
{text}

Output format (valid JSON only, no text outside JSON):
{{
  "2_mark": ["Q1", "Q2", "Q3", "Q4", "Q5"],
  "13_mark": ["Q1", "Q2"]
}}
"""
    try:
        response = co.chat(model="command-a-03-2025", message=prompt, temperature=0.3)
        raw = response.text.strip()
        # print("🧾 Raw Cohere Output:\n", raw)

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            start, end = raw.find("{"), raw.rfind("}")
            if start != -1 and end != -1:
                cleaned = raw[start:end + 1]
                data = json.loads(cleaned)
            else:
                raise HTTPException(status_code=500, detail="Malformed JSON from Cohere")

        return {
            "2_mark": data.get("2_mark", []),
            "13_mark": data.get("13_mark", [])
        }

    except Exception as e:
        print(f"[Exam Generation Error] {e}")
        raise HTTPException(status_code=500, detail="Failed to generate exam questions")

