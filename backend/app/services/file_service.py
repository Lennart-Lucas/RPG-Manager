from __future__ import annotations

from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.file import ResourceFile
from app.schemas.resources import FileCreate, FileUpdate
from app.services import author_service
from app.services.resource_common import validate_name, validate_url


async def list_files(session: AsyncSession, user_id: int) -> list[ResourceFile]:
    result = await session.execute(
        select(ResourceFile)
        .where(
            ResourceFile.user_id == user_id, ResourceFile.deleted_at.is_(None)
        )
        .order_by(ResourceFile.name.asc())
    )
    return list(result.scalars().all())


async def get_file(
    session: AsyncSession, user_id: int, file_id: int
) -> ResourceFile:
    resource = await session.get(ResourceFile, file_id)
    if (
        resource is None
        or resource.user_id != user_id
        or resource.deleted_at is not None
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    return resource


async def create_file(
    session: AsyncSession, user_id: int, data: FileCreate
) -> ResourceFile:
    await author_service.get_author(session, user_id, data.author_id)
    resource = ResourceFile(
        user_id=user_id,
        author_id=data.author_id,
        name=validate_name(data.name),
        source=validate_url(data.source),
        processed=data.processed,
    )
    session.add(resource)
    await session.flush()
    await session.refresh(resource)
    return resource


async def update_file(
    session: AsyncSession, user_id: int, file_id: int, data: FileUpdate
) -> ResourceFile:
    resource = await get_file(session, user_id, file_id)
    if data.author_id is not None:
        await author_service.get_author(session, user_id, data.author_id)
        resource.author_id = data.author_id
    if data.name is not None:
        resource.name = validate_name(data.name)
    if data.source is not None:
        # Allow clearing source with empty string
        resource.source = validate_url(data.source or None)
    if data.processed is not None:
        resource.processed = data.processed
    await session.flush()
    await session.refresh(resource)
    return resource


async def delete_file(
    session: AsyncSession, user_id: int, file_id: int
) -> None:
    resource = await get_file(session, user_id, file_id)
    resource.deleted_at = datetime.now(UTC)
    await session.flush()
