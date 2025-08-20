import json
import os
from dotenv import load_dotenv
from cohere import Client
from pathlib import Path
from fastapi import HTTPException
import re
import requests
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
        response = co.chat(message=prompt, model="command-r", temperature=0.3)

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


def fetch_material_documents():
    try:
        res = supabase.table("quizzes").select("pdf_url").execute()
        urls = [item["pdf_url"] for item in res.data if item.get("pdf_url")]

        docs = []

        for url in urls:
            response = requests.get(url)
            with pdfplumber.open(io.BytesIO(response.content)) as pdf:
                text = "\n".join([page.extract_text() or "" for page in pdf.pages])
                docs.append({
                    "title": url.split("/")[-1],
                    "text": text[:2000]  # Trim to avoid overloading the model
                })

        return docs
    except Exception as e:
        print(f"[Material Fetch Error] {e}")
        return []


def ask_chatbot(question: str):
    try:
        documents = fetch_material_documents()

        response = co.chat(
            message=question,
            documents=documents,
            model="command-r"
        )
        return response.text
    except Exception as e:
        print(f"[Chatbot Error] {e}")
        raise HTTPException(status_code=500, detail="Chatbot failed to respond.")
