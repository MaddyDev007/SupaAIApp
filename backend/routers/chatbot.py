from fastapi import APIRouter, Body
from services.cohere_api import ask_chatbot

router = APIRouter()

@router.post("/")
async def chat(data: dict = Body(...)):
    question = data.get("question")
    if not question:
        return {"error": "Missing question"}
    
    answer = ask_chatbot(question)
    return {"answer": answer}
