# backend/routers/chatbot.py

from fastapi import APIRouter, Body, HTTPException
from services.cohere_api import ask_chatbot

router = APIRouter()

@router.post("/")
async def chat(data: dict = Body(...)):
    question = data.get("question")
    class_id = data.get("class_id")  # ✅ NEW

    if not question:
        raise HTTPException(status_code=400, detail="Missing question")

    if not class_id:
        raise HTTPException(status_code=400, detail="Missing class_id")

    answer = await ask_chatbot(
        question=question,
        class_id=class_id,   # ✅ PASS CLASS CONTEXT
    )

    return {"answer": answer}
