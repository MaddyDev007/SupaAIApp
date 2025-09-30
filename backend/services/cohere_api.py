import json
import os
from dotenv import load_dotenv
from cohere import Client
from pathlib import Path
from fastapi import HTTPException
import re
import asyncio
import httpx
import pdfplumber
import io
from supabase import create_client

# Load environment variables
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")
co = Client(os.getenv("COHERE_API_KEY"))

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


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
{text[:2000]}
"""

    try:
        response = co.chat(message=prompt, model="command-a-03-2025", temperature=0.3)

        raw = response.text.strip()
        print("🧾 Cohere raw output:\n", raw)

        # Try strict JSON
        try:
            return json.loads(raw)
        except:
            # Try extracting array from text
            match = re.search(r'\[\s*{.*}\s*]', raw, re.DOTALL)
            if match:
                return json.loads(match.group())
            raise HTTPException(status_code=500, detail="Malformed JSON from Cohere")

    except Exception as e:
        print(f"[Cohere Error] {e}")
        raise HTTPException(status_code=500, detail="Failed to generate structured questions")


async def fetch_material_documents():
    """Fetch PDFs from Supabase and extract text (async)."""
    try:
        res = supabase.table("quizzes").select("pdf_url").execute()
        urls = [item["pdf_url"] for item in res.data if item.get("pdf_url")]

        docs = []
        async with httpx.AsyncClient(timeout=60.0) as client:
            for url in urls:
                r = await client.get(url)
                content = r.content

                # pdfplumber is blocking → run in thread
                def extract_text(data: bytes):
                    with pdfplumber.open(io.BytesIO(data)) as pdf:
                        return "\n".join([page.extract_text() or "" for page in pdf.pages])

                text = await asyncio.get_event_loop().run_in_executor(None, extract_text, content)
                docs.append({
                    "title": url.split("/")[-1],
                    "text": text[:2000]
                })

        return docs
    except Exception as e:
        print(f"[Material Fetch Error] {e}")
        return []


async def ask_chatbot(question: str):
    """Ask chatbot with optional documents (async)."""
    try:
        documents = await fetch_material_documents()

        # cohere client is sync, so run it in executor
        def run_cohere():
            return co.chat(
                model="command-a-03-2025",
                message=question,
                documents=documents,
            ).text

        answer = await asyncio.get_event_loop().run_in_executor(None, run_cohere)
        return answer

    except Exception as e:
        print(f"[Chatbot Error] {e}")
        raise HTTPException(status_code=500, detail="Chatbot failed to respond.")

def generate_exam_questions(text: str):
    prompt = f"""
    You are an exam question generator.
    Based on the following study material, generate:
    - 5 short 2-mark questions (one or two sentences, direct answers).
    - 2 long 13-mark questions (essay type, analytical, detailed).

    Study Material:
    {text[:2000]}

    Output format (valid JSON only, no text outside JSON):
    {{
      "2_mark": ["Q1", "Q2", ...],
      "13_mark": ["Q1", "Q2"]
    }}
    """

    try:
        # ✅ Correct Cohere API call
        response = co.chat(
            model="command-a-03-2025",
            message=prompt,     # not "messages"
            temperature=0.3
        )

        raw = response.text.strip()
        print("🧾 Raw Cohere Output:\n", raw)

        # ✅ Try direct JSON parsing
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            # Extract JSON object safely
            start = raw.find("{")
            end = raw.rfind("}")
            if start != -1 and end != -1:
                cleaned = raw[start:end+1]
                return json.loads(cleaned)

            raise HTTPException(status_code=500, detail="Malformed JSON from Cohere")

    except Exception as e:
        print(f"[Exam Generation Error] {e}")
        raise HTTPException(status_code=500, detail="Failed to generate exam questions")
