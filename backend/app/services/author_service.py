from __future__ import annotations

from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.author import Author
from app.models.file import ResourceFile
from app.schemas.resources import AuthorCreate, AuthorUpdate
from app.services.resource_common import normalize_links, validate_name


async def list_authors(session: AsyncSession, user_id: int) -> list[Author]:
    result = await session.execute(
        select(Author)
        .where(Author.user_id == user_id, Author.deleted_at.is_(None))
        .order_by(Author.name.asc())
    )
    return list(result.scalars().all())


async def get_author(
    session: AsyncSession, user_id: int, author_id: int
) -> Author:
    author = await session.get(Author, author_id)
    if (
        author is None
        or author.user_id != user_id
        or author.deleted_at is not None
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Author not found"
        )
    return author


async def create_author(
    session: AsyncSession, user_id: int, data: AuthorCreate
) -> Author:
    author = Author(
        user_id=user_id,
        name=validate_name(data.name),
        links=normalize_links([link.model_dump() for link in data.links]),
    )
    session.add(author)
    await session.flush()
    await session.refresh(author)
    return author


async def update_author(
    session: AsyncSession, user_id: int, author_id: int, data: AuthorUpdate
) -> Author:
    author = await get_author(session, user_id, author_id)
    if data.name is not None:
        author.name = validate_name(data.name)
    if data.links is not None:
        author.links = normalize_links(
            [link.model_dump() for link in data.links]
        )
    await session.flush()
    await session.refresh(author)
    return author


async def delete_author(
    session: AsyncSession, user_id: int, author_id: int
) -> None:
    author = await get_author(session, user_id, author_id)
    active_files = await session.execute(
        select(ResourceFile.id).where(
            ResourceFile.author_id == author_id,
            ResourceFile.user_id == user_id,
            ResourceFile.deleted_at.is_(None),
        ).limit(1)
    )
    if active_files.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Delete or reassign this author's files first",
        )
    author.deleted_at = datetime.now(UTC)
    await session.flush()
