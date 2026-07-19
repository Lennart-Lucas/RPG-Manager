from __future__ import annotations

from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.catalog_item import CatalogItem, CatalogKind
from app.schemas.catalog import CatalogItemCreate, CatalogItemUpdate
from app.services.resource_common import validate_name


async def list_items(
    session: AsyncSession, user_id: int, kind: CatalogKind
) -> list[CatalogItem]:
    result = await session.execute(
        select(CatalogItem)
        .where(
            CatalogItem.user_id == user_id,
            CatalogItem.kind == kind.value,
            CatalogItem.deleted_at.is_(None),
        )
        .order_by(CatalogItem.name.asc())
    )
    return list(result.scalars().all())


async def get_item(
    session: AsyncSession, user_id: int, kind: CatalogKind, item_id: int
) -> CatalogItem:
    item = await session.get(CatalogItem, item_id)
    if (
        item is None
        or item.user_id != user_id
        or item.kind != kind.value
        or item.deleted_at is not None
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Item not found"
        )
    return item


async def create_item(
    session: AsyncSession,
    user_id: int,
    kind: CatalogKind,
    data: CatalogItemCreate,
) -> CatalogItem:
    item = CatalogItem(
        user_id=user_id,
        kind=kind.value,
        name=validate_name(data.name),
    )
    session.add(item)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An item with this name already exists",
        ) from exc
    await session.refresh(item)
    return item


async def update_item(
    session: AsyncSession,
    user_id: int,
    kind: CatalogKind,
    item_id: int,
    data: CatalogItemUpdate,
) -> CatalogItem:
    item = await get_item(session, user_id, kind, item_id)
    item.name = validate_name(data.name)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An item with this name already exists",
        ) from exc
    await session.refresh(item)
    return item


async def delete_item(
    session: AsyncSession, user_id: int, kind: CatalogKind, item_id: int
) -> None:
    item = await get_item(session, user_id, kind, item_id)
    item.deleted_at = datetime.now(UTC)
    await session.flush()
