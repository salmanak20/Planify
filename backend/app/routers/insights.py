"""Protected Smart Insights endpoint."""

import asyncio
import json
import time
from collections import deque
from math import ceil

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import ValidationError

from app.core.config import settings
from app.core.firebase_auth import require_firebase_user
from app.schemas.insights import SmartInsightRequest, SmartInsightResponse

router = APIRouter(prefix="/insights", tags=["Insights"])

_MAX_BODY_BYTES = 8192
_RATE_LIMIT_REQUESTS = 10
_RATE_LIMIT_WINDOW_SECONDS = 60
_request_times: dict[str, deque[float]] = {}
_rate_limit_lock = asyncio.Lock()


async def _check_rate_limit(uid: str) -> None:
    now = time.monotonic()
    cutoff = now - _RATE_LIMIT_WINDOW_SECONDS
    async with _rate_limit_lock:
        timestamps = _request_times.setdefault(uid, deque())
        while timestamps and timestamps[0] <= cutoff:
            timestamps.popleft()
        if len(timestamps) >= _RATE_LIMIT_REQUESTS:
            retry_after = max(1, ceil(timestamps[0] + _RATE_LIMIT_WINDOW_SECONDS - now))
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Smart Insight request limit reached. Try again shortly.",
                headers={"Retry-After": str(retry_after)},
            )
        timestamps.append(now)

        # Bound memory use if many distinct authenticated users hit this worker.
        if len(_request_times) > 4096:
            expired_uids = [
                user_id
                for user_id, user_times in _request_times.items()
                if not user_times or user_times[-1] <= cutoff
            ]
            for user_id in expired_uids:
                _request_times.pop(user_id, None)


async def _read_payload(request: Request) -> SmartInsightRequest:
    if request.headers.get("content-type", "").split(";", 1)[0].strip().lower() != "application/json":
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Content-Type must be application/json.",
        )

    body = bytearray()
    async for chunk in request.stream():
        body.extend(chunk)
        if len(body) > _MAX_BODY_BYTES:
            raise HTTPException(
                status_code=413,
                detail="Request body is too large.",
            )

    try:
        return SmartInsightRequest.model_validate(json.loads(body))
    except (json.JSONDecodeError, UnicodeDecodeError, ValidationError, ValueError):
        # Avoid echoing task/note titles in validation responses.
        raise HTTPException(
            status_code=422,
            detail="Invalid Smart Insight request payload.",
        ) from None


@router.post("/smart", response_model=SmartInsightResponse)
async def generate_smart_insight(
    request: Request,
    response: Response,
    firebase_user: dict = Depends(require_firebase_user),
) -> SmartInsightResponse:
    api_key = settings.GEMINI_API_KEY
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Smart Insights are not configured.",
        )

    payload = await _read_payload(request)
    await _check_rate_limit(str(firebase_user["uid"]))

    titles = [*payload.tasks, *payload.notes]
    if not titles:
        raise HTTPException(
            status_code=422,
            detail="Add at least one task or note title.",
        )

    prompt = (
        "You are a productivity assistant. Based only on these pending tasks "
        f"and recent note titles, give one concise, motivating, actionable "
        f"focus suggestion in no more than two sentences.\n"
        f"Pending tasks: {json.dumps(payload.tasks, ensure_ascii=False)}\n"
        f"Recent notes: {json.dumps(payload.notes, ensure_ascii=False)}"
    )
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{settings.GEMINI_MODEL}:generateContent"
    )

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(20.0)) as client:
            provider_response = await client.post(
                url,
                headers={"x-goog-api-key": api_key},
                json={
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {"maxOutputTokens": 128},
                },
            )
        if provider_response.status_code >= 400:
            raise ValueError("Gemini provider returned an error")
        provider_data = provider_response.json()
        parts = provider_data["candidates"][0]["content"]["parts"]
        insight = " ".join(
            part["text"].strip()
            for part in parts
            if isinstance(part, dict) and isinstance(part.get("text"), str)
        ).strip()
        if not insight:
            raise ValueError("Gemini provider returned no text")
    except Exception:
        # Provider exceptions and response bodies may contain sensitive data.
        # Keep them out of application logs and return a generic error.
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Smart Insight generation failed.",
        ) from None

    response.headers["Cache-Control"] = "no-store"
    return SmartInsightResponse(insight=insight[:500])
