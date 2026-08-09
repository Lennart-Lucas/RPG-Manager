"""Extract searchable markdown from catalog payloads and build match snippets."""

from __future__ import annotations

import re
from typing import Any

_WIKI_LINK = re.compile(
    r"!?\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]",
)
_MD_NOISE = re.compile(r"[*_#>`]+")
_WS = re.compile(r"\s+")

_TOP_LEVEL_MARKDOWN_KEYS = (
    "description",
    "founding",
    "motto",
    "type",
    "requirement",
    "text",
    "trigger",
    "body",
    "quote",
    "prereqRoleplay",
)

_SNIPPET_RADIUS = 55
_SNIPPET_MAX = 140


def _plain(text: str) -> str:
    cleaned = _WIKI_LINK.sub(
        lambda m: (m.group(3) or m.group(2) or "").strip(),
        text,
    )
    cleaned = _MD_NOISE.sub("", cleaned)
    return _WS.sub(" ", cleaned).strip()


def _add_string(out: list[str], value: Any) -> None:
    if isinstance(value, str):
        text = value.strip()
        if text:
            out.append(text)


def iter_markdown_strings(payload: dict[str, Any] | None) -> list[str]:
    """Collect prose/markdown strings from a catalog payload."""
    if not isinstance(payload, dict):
        return []

    out: list[str] = []

    for key in _TOP_LEVEL_MARKDOWN_KEYS:
        _add_string(out, payload.get(key))

    higher = payload.get("higherLevels")
    if isinstance(higher, dict):
        _add_string(out, higher.get("description"))

    overview = payload.get("overviewSections")
    if isinstance(overview, list):
        for section in overview:
            if not isinstance(section, dict):
                continue
            items = section.get("items")
            if not isinstance(items, list):
                continue
            for item in items:
                if isinstance(item, dict):
                    _add_string(out, item.get("description"))

    for list_key in ("features", "traits", "namedFeatures"):
        entries = payload.get(list_key)
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            _add_string(out, entry.get("description"))
            _add_string(out, entry.get("text"))
            _add_string(out, entry.get("contents"))

    sections = payload.get("sections")
    if isinstance(sections, list):
        for section in sections:
            if isinstance(section, dict):
                _add_string(out, section.get("contents"))
                _add_string(out, section.get("description"))
                _add_string(out, section.get("body"))

    features_by_level = payload.get("featuresByLevel")
    if isinstance(features_by_level, dict):
        for level_features in features_by_level.values():
            if not isinstance(level_features, list):
                continue
            for entry in level_features:
                if isinstance(entry, dict):
                    _add_string(out, entry.get("description"))
                    _add_string(out, entry.get("text"))

    return out


def markdown_snippet_for_query(
    payload: dict[str, Any] | None,
    query: str,
    *,
    max_len: int = _SNIPPET_MAX,
) -> str | None:
    """Return a plain-text excerpt around the first markdown match, or None."""
    needle = query.strip()
    if not needle:
        return None
    needle_cf = needle.casefold()

    for raw in iter_markdown_strings(payload):
        plain = _plain(raw)
        if not plain:
            continue
        idx = plain.casefold().find(needle_cf)
        if idx < 0:
            continue
        start = max(0, idx - _SNIPPET_RADIUS)
        end = min(len(plain), idx + len(needle) + _SNIPPET_RADIUS)
        excerpt = plain[start:end].strip()
        if start > 0:
            excerpt = f"…{excerpt}"
        if end < len(plain):
            excerpt = f"{excerpt}…"
        if len(excerpt) > max_len:
            excerpt = f"{excerpt[: max_len - 1].rstrip()}…"
        return excerpt
    return None


def name_matches_query(name: str, query: str) -> bool:
    needle = query.strip()
    if not needle:
        return True
    return needle.casefold() in name.casefold()
