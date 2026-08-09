from __future__ import annotations

import re
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.catalog_item import CatalogItem
from app.models.catalog_link import CatalogLink

# kind -> payload field paths (dot-separated) that may contain wiki links
LINKABLE_FIELDS: dict[str, tuple[str, ...]] = {
    "spells": ("description", "higherLevels.description"),
    "spell_tags": ("description",),
    "features": ("text",),
    "items": ("description",),
    "creatures": ("trigger",),
    "conditions": ("description",),
    "damage_types": ("description",),
    "races": ("description",),
    "classes": ("description",),
    "subclasses": ("description",),
    "item_properties": ("description",),
    "rules": ("description",),
    "transformations": ("description",),
    "locations": ("description",),
    "characters": ("description",),
    "organisations": ("description", "founding", "type", "motto"),
    "events": ("description",),
    "lore": ("description",),
    "campaigns": ("description",),
    "sessions": ("description",),
}

WIKI_LINK_RE = re.compile(
    r"(!?)\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]"
)


def extract_wiki_refs(text: str) -> list[tuple[str, str]]:
    """Return unique (kind, target) pairs referenced in text.

    Target is normally a numeric id string; legacy name-based targets are
    also returned until migration rewrites them.
    """
    seen: set[tuple[str, str]] = set()
    refs: list[tuple[str, str]] = []
    for match in WIKI_LINK_RE.finditer(text or ""):
        kind = match.group(2).strip()
        target = match.group(3).strip()
        key = (kind, target)
        if key not in seen:
            seen.add(key)
            refs.append(key)
    return refs


def rewrite_wiki_targets_to_ids(
    text: str,
    *,
    resolve: dict[tuple[str, str], int],
) -> str:
    """Rewrite name-based wiki links to id-based using resolve[(kind, name_cf)] -> id.

    Links whose second segment is already all digits are left unchanged.
    Unresolved name links are left unchanged.
    """
    if not text:
        return text

    def _replace(match: re.Match[str]) -> str:
        bang = match.group(1) or ""
        kind = match.group(2).strip()
        target = match.group(3).strip()
        alias = match.group(4)
        if target.isdigit():
            return match.group(0)
        item_id = resolve.get((kind.lower(), target.casefold()))
        if item_id is None:
            return match.group(0)
        if alias:
            return f"{bang}[[{kind}/{item_id}|{alias}]]"
        return f"{bang}[[{kind}/{item_id}]]"

    return WIKI_LINK_RE.sub(_replace, text)


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


async def _find_by_alias(
    session: AsyncSession, *, user_id: int, kind: str, alias: str
) -> CatalogItem | None:
    needle = alias.casefold()
    if not needle:
        return None
    result = await session.execute(
        select(CatalogItem).where(
            CatalogItem.user_id == user_id,
            CatalogItem.kind == kind,
            CatalogItem.deleted_at.is_(None),
        )
    )
    for candidate in result.scalars().all():
        raw = (candidate.payload or {}).get("aliases")
        if not isinstance(raw, list):
            continue
        for entry in raw:
            if isinstance(entry, str) and entry.strip().casefold() == needle:
                return candidate
    return None


async def _resolve_wiki_target(
    session: AsyncSession,
    *,
    user_id: int,
    kind: str,
    target: str,
) -> CatalogItem | None:
    """Resolve kind/target where target is an id string or legacy name/alias."""
    if target.isdigit():
        result = await session.execute(
            select(CatalogItem).where(
                CatalogItem.user_id == user_id,
                CatalogItem.kind == kind,
                CatalogItem.id == int(target),
                CatalogItem.deleted_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    result = await session.execute(
        select(CatalogItem).where(
            CatalogItem.user_id == user_id,
            CatalogItem.kind == kind,
            CatalogItem.name == target,
            CatalogItem.deleted_at.is_(None),
        )
    )
    item = result.scalar_one_or_none()
    if item is not None:
        return item
    if kind in {"locations", "organisations", "races"}:
        return await _find_by_alias(
            session, user_id=user_id, kind=kind, alias=target
        )
    return None


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
        for kind, target in extract_wiki_refs(text):
            resolved = await _resolve_wiki_target(
                session,
                user_id=item.user_id,
                kind=kind,
                target=target,
            )
            if resolved is None:
                continue
            desired.add((resolved.id, field_key))

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
    """No-op: wiki links use stable catalog ids, so renames need no rewrite."""
    return
