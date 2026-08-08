"""Rewrite wiki links in catalog payloads from kind/name to kind/id.

Revision ID: 009
Revises: 008
Create Date: 2026-08-08

"""

from __future__ import annotations

import json
import re
from copy import deepcopy
from typing import Any, Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "009"
down_revision: Union[str, None] = "008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

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
    "campaigns": ("description",),
    "sessions": ("description",),
}

WIKI_LINK_RE = re.compile(
    r"(!?)\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]"
)


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


def _rewrite_text(
    text: str, resolve: dict[tuple[str, str], int]
) -> str:
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


def _extract_refs(text: str) -> list[tuple[str, str]]:
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


def upgrade() -> None:
    bind = op.get_bind()

    rows = bind.execute(
        sa.text(
            """
            SELECT id, user_id, kind, name, payload
            FROM catalog_items
            WHERE deleted_at IS NULL
            """
        )
    ).mappings().all()

    # (user_id, kind_lower, name_cf) -> id
    by_name: dict[tuple[int, str, str], int] = {}
    # (user_id, kind_lower, alias_cf) -> id for locations/orgs
    by_alias: dict[tuple[int, str, str], int] = {}
    items_by_id: dict[int, dict[str, Any]] = {}

    for row in rows:
        item_id = int(row["id"])
        user_id = int(row["user_id"])
        kind = str(row["kind"])
        name = str(row["name"])
        payload = row["payload"]
        if isinstance(payload, str):
            payload = json.loads(payload)
        if not isinstance(payload, dict):
            payload = {}
        items_by_id[item_id] = {
            "id": item_id,
            "user_id": user_id,
            "kind": kind,
            "name": name,
            "payload": payload,
        }
        by_name[(user_id, kind.lower(), name.casefold())] = item_id
        if kind in {"locations", "organisations"}:
            raw = payload.get("aliases")
            if isinstance(raw, list):
                for entry in raw:
                    if isinstance(entry, str) and entry.strip():
                        by_alias[
                            (user_id, kind.lower(), entry.strip().casefold())
                        ] = item_id

    def resolve_for_user(user_id: int) -> dict[tuple[str, str], int]:
        out: dict[tuple[str, str], int] = {}
        for (uid, kind, name_cf), iid in by_name.items():
            if uid == user_id:
                out[(kind, name_cf)] = iid
        for (uid, kind, alias_cf), iid in by_alias.items():
            if uid == user_id:
                out.setdefault((kind, alias_cf), iid)
        return out

    # Rewrite payloads.
    for item in items_by_id.values():
        fields = LINKABLE_FIELDS.get(item["kind"], ())
        if not fields:
            continue
        resolve = resolve_for_user(item["user_id"])
        payload = deepcopy(item["payload"])
        changed = False
        for field_key in fields:
            text = _get_nested(payload, field_key)
            if not text:
                continue
            rewritten = _rewrite_text(text, resolve)
            if rewritten != text:
                _set_nested(payload, field_key, rewritten)
                changed = True
        if changed:
            item["payload"] = payload
            bind.execute(
                sa.text(
                    """
                    UPDATE catalog_items
                    SET payload = CAST(:payload AS jsonb)
                    WHERE id = :id
                    """
                ),
                {"id": item["id"], "payload": json.dumps(payload)},
            )

    # Rebuild catalog_links from rewritten payloads.
    bind.execute(sa.text("DELETE FROM catalog_links"))

    id_index: dict[tuple[int, str, int], int] = {}
    for item in items_by_id.values():
        id_index[(item["user_id"], item["kind"].lower(), item["id"])] = item[
            "id"
        ]

    for item in items_by_id.values():
        fields = LINKABLE_FIELDS.get(item["kind"], ())
        if not fields:
            continue
        user_id = item["user_id"]
        resolve_names = resolve_for_user(user_id)
        desired: set[tuple[int, str]] = set()
        for field_key in fields:
            text = _get_nested(item["payload"], field_key)
            if not text:
                continue
            for kind, target in _extract_refs(text):
                target_id: int | None = None
                if target.isdigit():
                    target_id = id_index.get(
                        (user_id, kind.lower(), int(target))
                    )
                else:
                    target_id = resolve_names.get(
                        (kind.lower(), target.casefold())
                    )
                if target_id is None:
                    continue
                desired.add((target_id, field_key))
        for target_id, field_key in desired:
            bind.execute(
                sa.text(
                    """
                    INSERT INTO catalog_links
                        (user_id, source_item_id, target_item_id, field_key)
                    VALUES
                        (:user_id, :source_id, :target_id, :field_key)
                    """
                ),
                {
                    "user_id": user_id,
                    "source_id": item["id"],
                    "target_id": target_id,
                    "field_key": field_key,
                },
            )


def downgrade() -> None:
    # Irreversible data migration (ids cannot be mapped back to historical names
    # reliably if records were renamed after upgrade).
    pass
