from __future__ import annotations

import re
from copy import deepcopy
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.catalog_item import CatalogItem
from app.models.catalog_link import CatalogLink

# kind -> payload field paths (dot-separated) that may contain wiki links
LINKABLE_FIELDS: dict[str, tuple[str, ...]] = {
    "spells": ("description", "higherLevels.description"),
}

WIKI_LINK_RE = re.compile(
    r"\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]"
)


def extract_wiki_refs(text: str) -> list[tuple[str, str]]:
    """Return unique (kind, name) pairs referenced in text."""
    seen: set[tuple[str, str]] = set()
    refs: list[tuple[str, str]] = []
    for match in WIKI_LINK_RE.finditer(text or ""):
        kind = match.group(1).strip()
        name = match.group(2).strip()
        key = (kind, name)
        if key not in seen:
            seen.add(key)
            refs.append(key)
    return refs


def rewrite_wiki_names(
    text: str, *, kind: str, old_name: str, new_name: str
) -> str:
    if not text or old_name == new_name:
        return text
    pattern = re.compile(
        rf"\[\[{re.escape(kind)}/{re.escape(old_name)}(?:\|([^\]]+))?\]\]"
    )

    def _replace(match: re.Match[str]) -> str:
        alias = match.group(1)
        if alias:
            return f"[[{kind}/{new_name}|{alias}]]"
        return f"[[{kind}/{new_name}]]"

    return pattern.sub(_replace, text)


def _get_nested(payload: dict[str, Any] | None, path: str) -> str | None:
    if not payload:
        return None
    current: Any = payload
    for part in path.split("."):
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    return current if isinstance(current, str) else None


def _set_nested(payload: dict[str, Any], path: str, value: str) -> None:
    parts = path.split(".")
    current: dict[str, Any] = payload
    for part in parts[:-1]:
        next_value = current.get(part)
        if not isinstance(next_value, dict):
            next_value = {}
            current[part] = next_value
        current = next_value
    current[parts[-1]] = value


async def sync_links_for_item(
    session: AsyncSession, item: CatalogItem
) -> None:
    field_keys = LINKABLE_FIELDS.get(item.kind, ())
    # Clear existing edges for this source (all registered fields).
    existing = await session.execute(
        select(CatalogLink).where(CatalogLink.source_item_id == item.id)
    )
    for link in existing.scalars().all():
        await session.delete(link)

    if not field_keys:
        return

    desired: set[tuple[int, str]] = set()  # (target_id, field_key)
    for field_key in field_keys:
        text = _get_nested(item.payload, field_key)
        if not text:
            continue
        for kind, name in extract_wiki_refs(text):
            result = await session.execute(
                select(CatalogItem).where(
                    CatalogItem.user_id == item.user_id,
                    CatalogItem.kind == kind,
                    CatalogItem.name == name,
                    CatalogItem.deleted_at.is_(None),
                )
            )
            target = result.scalar_one_or_none()
            if target is None:
                continue
            desired.add((target.id, field_key))

    for target_id, field_key in desired:
        session.add(
            CatalogLink(
                user_id=item.user_id,
                source_item_id=item.id,
                target_item_id=target_id,
                field_key=field_key,
            )
        )


async def propagate_rename(
    session: AsyncSession,
    *,
    target: CatalogItem,
    old_name: str,
    new_name: str,
) -> None:
    if old_name == new_name:
        return

    inbound = await session.execute(
        select(CatalogLink).where(CatalogLink.target_item_id == target.id)
    )
    links = list(inbound.scalars().all())
    if not links:
        return

    # Group by source to rewrite each payload once.
    by_source: dict[int, list[CatalogLink]] = {}
    for link in links:
        by_source.setdefault(link.source_item_id, []).append(link)

    for source_id, source_links in by_source.items():
        source = await session.get(CatalogItem, source_id)
        if source is None or source.deleted_at is not None:
            continue
        payload = deepcopy(source.payload) if source.payload else {}
        changed = False
        for link in source_links:
            text = _get_nested(payload, link.field_key)
            if text is None:
                continue
            rewritten = rewrite_wiki_names(
                text,
                kind=target.kind,
                old_name=old_name,
                new_name=new_name,
            )
            if rewritten != text:
                _set_nested(payload, link.field_key, rewritten)
                changed = True
        if changed:
            source.payload = payload
