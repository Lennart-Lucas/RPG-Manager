from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.routes.auth import limiter
from app.dependencies import (
    campaign_scope_user_id,
    get_current_dm_user,
    get_db,
)
from app.models.user import User
from app.schemas.extract import (
    ExtractJobRequest,
    ExtractJobResponse,
    ProcessClassRequest,
    ProcessClassResponse,
    ProcessSpellRequest,
    ProcessSpellResponse,
)
from app.services.extract import claude_client
from app.services.extract.pipeline import run_extract_job
from app.services.extract.process_class import process_class_record
from app.services.extract.process_spell import process_spell_record

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


def _raise_claude_http(exc: claude_client.ClaudeError) -> None:
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


@router.post("/jobs", response_model=ExtractJobResponse)
@limiter.limit("10/minute")
async def create_extract_job(
    request: Request,
    body: ExtractJobRequest,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
    api_key: str = Depends(_require_anthropic_key),
) -> ExtractJobResponse:
    if not user.ai_integration:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="AI integration is disabled. Enable it in Preferences.",
        )
    if body.kind not in ("spells", "items", "conditions"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only kind=spells, kind=items, or kind=conditions is supported",
        )
    if len(body.text) > 1_000_000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Text exceeds maximum length",
        )

    try:
        return await run_extract_job(
            session=session,
            user_id=await campaign_scope_user_id(session, user),
            api_key=api_key,
            request=body,
        )
    except claude_client.ClaudeError as exc:
        _raise_claude_http(exc)


@router.post("/process-class", response_model=ProcessClassResponse)
@limiter.limit("10/minute")
async def process_class(
    request: Request,
    body: ProcessClassRequest,
    user: User = Depends(get_current_dm_user),
    api_key: str = Depends(_require_anthropic_key),
) -> ProcessClassResponse:
    if not user.ai_integration:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="AI integration is disabled. Enable it in Preferences.",
        )
    try:
        payload = await process_class_record(
            api_key=api_key,
            kind=body.kind,
            prompt=body.prompt,
            current=body.current,
            definition=body.definition,
        )
    except claude_client.ClaudeError as exc:
        _raise_claude_http(exc)
    return ProcessClassResponse(payload=payload)


@router.post("/process-spell", response_model=ProcessSpellResponse)
@limiter.limit("10/minute")
async def process_spell(
    request: Request,
    body: ProcessSpellRequest,
    user: User = Depends(get_current_dm_user),
    api_key: str = Depends(_require_anthropic_key),
) -> ProcessSpellResponse:
    if not user.ai_integration:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="AI integration is disabled. Enable it in Preferences.",
        )
    try:
        payload = await process_spell_record(
            api_key=api_key,
            prompt=body.prompt,
            current=body.current,
            definition=body.definition,
        )
    except claude_client.ClaudeError as exc:
        _raise_claude_http(exc)
    return ProcessSpellResponse(payload=payload)
