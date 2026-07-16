from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_dm_user, get_db
from app.models.user import User
from app.schemas.resources import (
    AuthorCreate,
    AuthorResponse,
    AuthorUpdate,
)
from app.services import author_service

router = APIRouter(prefix="/authors", tags=["authors"])


@router.get("", response_model=list[AuthorResponse])
async def list_authors(
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> list[AuthorResponse]:
    authors = await author_service.list_authors(session, user.id)
    return [AuthorResponse.model_validate(a) for a in authors]


@router.post("", response_model=AuthorResponse, status_code=201)
async def create_author(
    body: AuthorCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> AuthorResponse:
    author = await author_service.create_author(session, user.id, body)
    return AuthorResponse.model_validate(author)


@router.get("/{author_id}", response_model=AuthorResponse)
async def get_author(
    author_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> AuthorResponse:
    author = await author_service.get_author(session, user.id, author_id)
    return AuthorResponse.model_validate(author)


@router.patch("/{author_id}", response_model=AuthorResponse)
async def update_author(
    author_id: int,
    body: AuthorUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> AuthorResponse:
    author = await author_service.update_author(
        session, user.id, author_id, body
    )
    return AuthorResponse.model_validate(author)


@router.delete("/{author_id}", status_code=204)
async def delete_author(
    author_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> None:
    await author_service.delete_author(session, user.id, author_id)
