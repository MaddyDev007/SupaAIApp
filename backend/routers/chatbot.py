"""Authenticated, class-scoped chatbot API with persistent conversation history."""

import asyncio
from typing import Any

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from security import authenticated_user, ensure_class_access, supabase_admin
from services.gemini_api import ask_chatbot_stream

router = APIRouter()

MAX_HISTORY_MESSAGES = 20
MAX_DISPLAY_MESSAGES = 100


class ChatSessionRequest(BaseModel):
    class_id: str = Field(min_length=1)


class ChatStreamRequest(BaseModel):
    question: str = Field(min_length=1, max_length=10000)
    class_id: str = Field(min_length=1)
    session_id: str = Field(min_length=1)


def _rows(response: Any) -> list[dict[str, Any]]:
    data = getattr(response, "data", None)
    if not isinstance(data, list):
        return []
    return data


def _find_session(user_id: str, class_id: str) -> dict[str, Any] | None:
    response = (
        supabase_admin.table("chat_sessions")
        .select("id, user_id, class_id, created_at, updated_at")
        .eq("user_id", user_id)
        .eq("class_id", class_id)
        .limit(1)
        .execute()
    )
    rows = _rows(response)
    return rows[0] if rows else None


def _get_or_create_session(user_id: str, class_id: str) -> dict[str, Any]:
    existing = _find_session(user_id, class_id)
    if existing:
        return existing

    try:
        response = (
            supabase_admin.table("chat_sessions")
            .insert({"user_id": user_id, "class_id": class_id})
            .select("id, user_id, class_id, created_at, updated_at")
            .execute()
        )
        rows = _rows(response)
        if rows:
            return rows[0]
    except Exception:
        # A concurrent first page-open may have inserted the unique
        # (user_id, class_id) session. Re-read before returning an error.
        existing = _find_session(user_id, class_id)
        if existing:
            return existing
        raise

    existing = _find_session(user_id, class_id)
    if existing:
        return existing
    raise HTTPException(status_code=500, detail="Could not create chat session")


def _get_owned_session(
    session_id: str, user_id: str, class_id: str
) -> dict[str, Any]:
    response = (
        supabase_admin.table("chat_sessions")
        .select("id, user_id, class_id")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .eq("class_id", class_id)
        .limit(1)
        .execute()
    )
    rows = _rows(response)
    if not rows:
        raise HTTPException(status_code=404, detail="Chat session not found")
    return rows[0]


def _load_messages(
    session_id: str, user_id: str, class_id: str, limit: int
) -> list[dict[str, Any]]:
    response = (
        supabase_admin.table("chat_messages")
        .select("id, role, content, created_at")
        .eq("session_id", session_id)
        .eq("user_id", user_id)
        .eq("class_id", class_id)
        .order("id", desc=True)
        .limit(limit)
        .execute()
    )
    rows = _rows(response)
    return list(reversed(rows))


def _save_message(
    session_id: str, user_id: str, class_id: str, role: str, content: str
) -> None:
    cleaned = content.strip()
    if not cleaned:
        return

    (
        supabase_admin.table("chat_messages")
        .insert({
            "session_id": session_id,
            "user_id": user_id,
            "class_id": class_id,
            "role": role,
            "content": cleaned,
        })
        .execute()
    )


@router.post("/session")
async def get_or_create_chat_session(
    payload: ChatSessionRequest,
    user: dict = Depends(authenticated_user),
):
    ensure_class_access(user["id"], payload.class_id)
    session = await asyncio.to_thread(
        _get_or_create_session, user["id"], payload.class_id
    )
    return {"session_id": session["id"]}


@router.get("/history")
async def get_chat_history(
    class_id: str = Query(..., min_length=1),
    session_id: str = Query(..., min_length=1),
    user: dict = Depends(authenticated_user),
):
    ensure_class_access(user["id"], class_id)
    await asyncio.to_thread(
        _get_owned_session, session_id, user["id"], class_id
    )
    messages = await asyncio.to_thread(
        _load_messages,
        session_id,
        user["id"],
        class_id,
        MAX_DISPLAY_MESSAGES,
    )
    return {
        "messages": [
            {
                "role": "user" if row["role"] == "user" else "bot",
                "msg": row["content"],
            }
            for row in messages
        ]
    }


@router.delete("/history")
async def clear_chat_history(
    class_id: str = Query(..., min_length=1),
    session_id: str = Query(..., min_length=1),
    user: dict = Depends(authenticated_user),
):
    ensure_class_access(user["id"], class_id)
    await asyncio.to_thread(
        _get_owned_session, session_id, user["id"], class_id
    )
    await asyncio.to_thread(
        lambda: (
            supabase_admin.table("chat_messages")
            .delete()
            .eq("session_id", session_id)
            .eq("user_id", user["id"])
            .eq("class_id", class_id)
            .execute()
        )
    )
    return {"status": "cleared"}


@router.post("/stream")
async def chat_stream(
    payload: ChatStreamRequest,
    user: dict = Depends(authenticated_user),
):
    user_id = user["id"]
    class_id = payload.class_id
    session_id = payload.session_id
    question = payload.question.strip()

    ensure_class_access(user_id, class_id)
    await asyncio.to_thread(
        _get_owned_session, session_id, user_id, class_id
    )

    # Load the previous turns before saving the current question, so Gemini
    # receives each message exactly once.
    history = await asyncio.to_thread(
        _load_messages,
        session_id,
        user_id,
        class_id,
        MAX_HISTORY_MESSAGES,
    )

    await asyncio.to_thread(
        _save_message, session_id, user_id, class_id, "user", question
    )

    async def persist_answer(answer: str) -> None:
        await asyncio.to_thread(
            _save_message,
            session_id,
            user_id,
            class_id,
            "assistant",
            answer,
        )

    return await ask_chatbot_stream(
        question=question,
        class_id=class_id,
        history=history,
        on_answer_complete=persist_answer,
    )
