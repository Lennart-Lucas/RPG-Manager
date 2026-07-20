from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.routes.auth import limiter
from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.extract import ExtractJobRequest, ExtractJobResponse
from app.services.extract import claude_client
from app.services.extract.pipeline import run_extract_job

router = APIRouter(prefix="/extract", tags=["extract"])

ANTHROPIC_HEADER = "X-Anthropic-Api-Key"


def _require_anthropic_key(
    x_anthropic_api_key: str | None = Header(default=None, alias=ANTHROPIC_HEADER),
) -> str:
    key = (x_anthropic_api_key or "").strip()
    if not key:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing X-Anthropic-Api-Key header. Add your API key in Preferences.",
        )
    return key


@router.post("/jobs", response_model=ExtractJobResponse)
@limiter.limit("10/minute")
async def create_extract_job(
    request: Request,
    body: ExtractJobRequest,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
    api_key: str = Depends(_require_anthropic_key),
) -> ExtractJobResponse:
    # #region agent log
    try:
        import json
        import time
        from pathlib import Path

        Path("/Users/lennart.lucas/Documents/Github/RPG-Manager/.cursor/debug-5823b4.log").open(
            "a"
        ).write(
            json.dumps(
                {
                    "sessionId": "5823b4",
                    "runId": "post-fix",
                    "hypothesisId": "A",
                    "location": "extract.py:create_extract_job",
                    "message": "extract handler entered with body model",
                    "data": {
                        "kind": getattr(body, "kind", None),
                        "text_len": len(getattr(body, "text", "") or ""),
                        "has_title": bool(getattr(body, "document_title", None)),
                    },
                    "timestamp": int(time.time() * 1000),
                }
            )
            + "\n"
        )
    except Exception:
        pass
    # #endregion
    if not user.ai_integration:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="AI integration is disabled. Enable it in Preferences.",
        )
    if body.kind != "spells":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only kind=spells is supported",
        )
    if len(body.text) > 1_000_000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Text exceeds maximum length",
        )

    try:
        return await run_extract_job(
            session=session,
            user_id=user.id,
            api_key=api_key,
            request=body,
        )
    except claude_client.ClaudeError as exc:
        code = (
            status.HTTP_502_BAD_GATEWAY
            if (exc.status_code is None or exc.status_code >= 500)
            else status.HTTP_400_BAD_REQUEST
        )
        if exc.status_code == 401:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Anthropic API rejected the key",
            ) from exc
        raise HTTPException(status_code=code, detail=str(exc)) from exc
