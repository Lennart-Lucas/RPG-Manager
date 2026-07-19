from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.data.default_skills import DEFAULT_SKILLS, is_default_skill_name
from app.models.catalog_item import CatalogItem, CatalogKind
from app.schemas.catalog import CatalogItemCreate, CatalogItemUpdate
from app.services import catalog_wiki
from app.services.resource_common import validate_name



async def ensure_default_skills(session: AsyncSession, user_id: int) -> None:
    """Create any missing base D&D skills for [user_id] (idempotent)."""
    result = await session.execute(
        select(CatalogItem).where(
            CatalogItem.user_id == user_id,
            CatalogItem.kind == CatalogKind.skills.value,
            CatalogItem.deleted_at.is_(None),
        )
    )
    existing = list(result.scalars().all())
    by_name = {item.name.casefold(): item for item in existing}

    created = False
    for name, attribute in DEFAULT_SKILLS:
        key = name.casefold()
        item = by_name.get(key)
        if item is None:
            session.add(
                CatalogItem(
                    user_id=user_id,
                    kind=CatalogKind.skills.value,
                    name=name,
                    payload={"attribute": attribute},
                )
            )
            created = True
            continue
        # Backfill attribute on legacy name-only rows.
        payload = item.payload if isinstance(item.payload, dict) else None
        current = payload.get("attribute") if payload else None
        if not isinstance(current, str) or not current.strip():
            item.payload = {"attribute": attribute}
            created = True

    if created:
        await session.flush()


async def list_items(
    session: AsyncSession, user_id: int, kind: CatalogKind
) -> list[CatalogItem]:
    if kind == CatalogKind.skills:
        await ensure_default_skills(session, user_id)

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


async def search_items(
    session: AsyncSession,
    user_id: int,
    query: str,
    *,
    limit: int = 20,
) -> list[CatalogItem]:
    q = query.strip()
    stmt = (
        select(CatalogItem)
        .where(
            CatalogItem.user_id == user_id,
            CatalogItem.deleted_at.is_(None),
        )
        .order_by(CatalogItem.name.asc())
        .limit(limit)
    )
    if q:
        stmt = stmt.where(CatalogItem.name.ilike(f"%{q}%"))
    result = await session.execute(stmt)
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


def _sync_embedded_name(payload: dict[str, Any] | None, name: str) -> dict[str, Any] | None:
    """Keep payload.name in sync when present (e.g. spell payloads)."""
    if payload is None:
        return None
    if "name" in payload:
        updated = dict(payload)
        updated["name"] = name
        return updated
    return payload


async def create_item(
    session: AsyncSession,
    user_id: int,
    kind: CatalogKind,
    data: CatalogItemCreate,
) -> CatalogItem:
    name = validate_name(data.name)
    payload = _sync_embedded_name(data.payload, name)
    item = CatalogItem(
        user_id=user_id,
        kind=kind.value,
        name=name,
        payload=payload,
    )
    session.add(item)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An item with this name already exists",
        ) from exc
    await catalog_wiki.sync_links_for_item(session, item)
    await session.flush()
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
    old_name = item.name

    if data.name is not None:
        item.name = validate_name(data.name)

    if data.payload is not None:
        item.payload = _sync_embedded_name(data.payload, item.name)
    elif data.name is not None and item.payload is not None:
        item.payload = _sync_embedded_name(item.payload, item.name)

    try:
        await session.flush()
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An item with this name already exists",
        ) from exc

    if data.name is not None and old_name != item.name:
        await catalog_wiki.propagate_rename(
            session,
            target=item,
            old_name=old_name,
            new_name=item.name,
        )

    await catalog_wiki.sync_links_for_item(session, item)
    await session.flush()
    await session.refresh(item)
    return item


async def delete_item(
    session: AsyncSession, user_id: int, kind: CatalogKind, item_id: int
) -> None:
    item = await get_item(session, user_id, kind, item_id)
    if kind == CatalogKind.skills and is_default_skill_name(item.name):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Default skills cannot be deleted",
        )
    item.deleted_at = datetime.now(UTC)
    await session.flush()

