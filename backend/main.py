# Validate mandatory settings before importing modules that create external clients.
# This ensures missing configuration fails once, immediately, and with safe messages.
from config import get_settings

settings = get_settings()

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from routers import upload, quiz, chatbot, question, results
from routers import delete


app = FastAPI()


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(request, exc: RequestValidationError):
    """Return a stable, client-safe error format for malformed request bodies."""

    details = []
    for error in exc.errors()[:25]:
        location = error.get("loc", ())
        field = ".".join(str(part) for part in location if part != "body")
        error_type = str(error.get("type", "invalid_value"))

        if error_type in {"json_invalid", "value_error.jsondecode"}:
            field = "body"
            message = "Request body must contain valid JSON."
        else:
            message = str(error.get("msg", "Invalid value."))

        details.append(
            {
                "field": field or "request",
                "message": message,
                "code": error_type,
            }
        )

    return JSONResponse(
        status_code=422,
        content={
            "error": "validation_error",
            "message": "Request payload is invalid. Check the details and try again.",
            "details": details,
        },
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace "*" with your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload.router, prefix="/upload")
app.include_router(quiz.router, prefix="/quiz")
app.include_router(chatbot.router, prefix="/chatbot")
app.include_router(question.router, prefix="/question")
app.include_router(delete.router, prefix="/delete", tags=["Delete"])
app.include_router(results.router, prefix="/results")


@app.api_route("/", methods=["GET", "HEAD"])
async def root():
    return {"status": "ok", "message": "SmartClass Backend running"}
