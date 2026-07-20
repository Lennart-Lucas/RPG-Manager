from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any

from pydantic import ValidationError

from app.services.extract.spell_schema import (
    SPELL_EXTRACT_JSON_SCHEMA,
    SpellExtractPayload,
)


@dataclass
class AnchorSpan:
    first_line: str
    last_line: str
    verified: bool
    start_index: int | None = None
    end_index: int | None = None
    entry_text: str | None = None
    name_hint: str | None = None


def _normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip())


def find_verbatim(haystack: str, needle: str) -> int:
    """Return start index of needle in haystack, preferring exact then normalized line match."""
    if not needle.strip():
        return -1
    exact = haystack.find(needle)
    if exact >= 0:
        return exact
    # Try line-normalized search
    needle_norm = _normalize_line(needle)
    for i, line in enumerate(haystack.splitlines()):
        if _normalize_line(line) == needle_norm:
            # Map back to character offset
            offset = 0
            for prev in haystack.splitlines(keepends=True)[:i]:
                offset += len(prev)
            return offset
    return -1


def verify_anchor_pair(
    source: str, first_line: str, last_line: str
) -> AnchorSpan:
    start = find_verbatim(source, first_line)
    if start < 0:
        return AnchorSpan(
            first_line=first_line,
            last_line=last_line,
            verified=False,
            name_hint=first_line.strip() or None,
        )
    # Search last line after start
    search_region = source[start:]
    last_rel = find_verbatim(search_region, last_line)
    if last_rel < 0:
        return AnchorSpan(
            first_line=first_line,
            last_line=last_line,
            verified=False,
            start_index=start,
            name_hint=first_line.strip() or None,
        )
    end = start + last_rel + len(last_line)
    # Extend to end of line containing last_line if possible
    nl = source.find("\n", end)
    if nl >= 0 and nl - end < 200:
        end = nl
    entry_text = source[start:end].strip()
    return AnchorSpan(
        first_line=first_line,
        last_line=last_line,
        verified=True,
        start_index=start,
        end_index=end,
        entry_text=entry_text,
        name_hint=first_line.strip() or None,
    )


def parse_anchor_response(raw: dict[str, Any] | list[Any]) -> list[dict[str, str]]:
    if isinstance(raw, list):
        items = raw
    elif isinstance(raw, dict):
        items = raw.get("entries") or raw.get("anchors") or []
    else:
        items = []
    out: list[dict[str, str]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        first = item.get("first_line") or item.get("firstLine") or ""
        last = item.get("last_line") or item.get("lastLine") or ""
        if isinstance(first, str) and isinstance(last, str) and first.strip():
            out.append({"first_line": first, "last_line": last or first})
    return out


ANCHOR_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "entries": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "first_line": {"type": "string"},
                    "last_line": {"type": "string"},
                },
                "required": ["first_line", "last_line"],
            },
        }
    },
    "required": ["entries"],
}


def extract_payload_or_raise(data: dict[str, Any]) -> SpellExtractPayload:
    return SpellExtractPayload.model_validate(data)


def try_parse_spell_payload(
    data: dict[str, Any],
) -> tuple[SpellExtractPayload | None, str | None]:
    try:
        return extract_payload_or_raise(data), None
    except ValidationError as exc:
        return None, str(exc)


def payload_to_dict(payload: SpellExtractPayload) -> dict[str, Any]:
    return payload.model_dump(mode="json", exclude_none=False)


def dumps_schema() -> str:
    return json.dumps(SPELL_EXTRACT_JSON_SCHEMA)
