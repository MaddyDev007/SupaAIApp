from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import upload, quiz, chatbot, question

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace "*" with your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include your routers with prefixes
app.include_router(upload.router, prefix="/upload")

app.include_router(quiz.router, prefix="/quiz") 

app.include_router(chatbot.router, prefix="/chatbot")

app.include_router(question.router, prefix="/question") 

@app.get("/")
async def root():
    return {"status": "ok", "message": "SmartClass Backend running"}