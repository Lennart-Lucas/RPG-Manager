from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from app.config import settings
from app.services.extract.condition_schema import CONDITION_EXTRACT_JSON_SCHEMA
from app.services.extract.item_schema import ITEM_EXTRACT_JSON_SCHEMA
from app.services.extract.spell_schema import SPELL_EXTRACT_JSON_SCHEMA
from app.services.extract.tier2_anchors import ANCHOR_JSON_SCHEMA

logger = logging.getLogger(__name__)

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"


class ClaudeError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


def _headers(api_key: str) -> dict[str, str]:
    return {
        "x-api-key": api_key,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
    }


def _tool_choice(name: str) -> dict[str, str]:
    return {"type": "tool", "name": name}


async def _messages_create(
    *,
    api_key: str,
    system: str,
    user: str,
    tools: list[dict[str, Any]],
    tool_name: str,
    max_tokens: int = 2048,
) -> dict[str, Any]:
    body = {
        "model": settings.anthropic_model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": [{"role": "user", "content": user}],
        "tools": tools,
        "tool_choice": _tool_choice(tool_name),
    }
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                ANTHROPIC_API_URL,
                headers=_headers(api_key),
                json=body,
            )
    except httpx.HTTPError as exc:
        # Never include api_key in error messages
        raise ClaudeError("Failed to reach Anthropic API") from exc

    if response.status_code >= 400:
        # Do not forward Anthropic body verbatim if it might echo headers;
        # use a short detail only.
        detail = "Anthropic API request failed"
        try:
            data = response.json()
            err = data.get("error") if isinstance(data, dict) else None
            if isinstance(err, dict) and isinstance(err.get("message"), str):
                msg = err["message"]
                # Strip anything that looks like a key
                if "sk-ant" not in msg and "api-key" not in msg.lower():
                    detail = msg[:300]
        except Exception:
            pass
        raise ClaudeError(detail, status_code=response.status_code)

    return response.json()


def _tool_input(response_json: dict[str, Any], tool_name: str) -> dict[str, Any]:
    content = response_json.get("content")
    if not isinstance(content, list):
        raise ClaudeError("Unexpected Anthropic response shape")
    for block in content:
        if (
            isinstance(block, dict)
            and block.get("type") == "tool_use"
            and block.get("name") == tool_name
        ):
            raw = block.get("input")
            if isinstance(raw, dict):
                return raw
            if isinstance(raw, str):
                parsed = json.loads(raw)
                if isinstance(parsed, dict):
                    return parsed
    raise ClaudeError("Anthropic response missing tool result")


EXTRACT_SYSTEM = (
    "You extract structured D&D 5e spell data from source text. "
    "Extract only what is explicitly present in the text. "
    "Use null for any field that is missing or unclear. "
    "Never invent, infer, or fill gaps. "
    "If the chunk is not a spell entry (cover, art credit, TOC, filler), "
    "leave name/level/school/description null and briefly say so in notes. "
    "Put area/emanation/flare/special range details into description or "
    "range-related fields when possible; use unknown_fields only for "
    "mechanical data that truly does not fit the schema. "
    "Do not put illustration credits, product titles, or page decoration "
    "into unknown_fields. "
    "Class and tag names should be plain strings as written in the source; "
    "leave tags empty unless the source explicitly lists tags."
)


async def extract_spell(
    *,
    api_key: str,
    entry_text: str,
) -> dict[str, Any]:
    tools = [
        {
            "name": "spell_extract",
            "description": "Structured spell fields extracted from the source text.",
            "input_schema": SPELL_EXTRACT_JSON_SCHEMA,
        }
    ]
    user = (
        "Extract the spell from the following source text into the spell_extract tool.\n\n"
        f"---\n{entry_text}\n---"
    )
    response = await _messages_create(
        api_key=api_key,
        system=EXTRACT_SYSTEM,
        user=user,
        tools=tools,
        tool_name="spell_extract",
    )
    return _tool_input(response, "spell_extract")


async def detect_anchors(
    *,
    api_key: str,
    section_text: str,
    kind: str = "spells",
) -> dict[str, Any]:
    if kind == "items":
        entry_label = "item"
        tool_name = "item_anchors"
    elif kind == "conditions":
        entry_label = "condition"
        tool_name = "condition_anchors"
    else:
        entry_label = "spell"
        tool_name = "spell_anchors"
    system = (
        f"You identify individual {entry_label} entry boundaries in RPG source text. "
        f"For each {entry_label} entry, quote the exact first line and exact last line "
        "verbatim from the source — do not paraphrase or normalize punctuation. "
        "Only include entries you can ground in the text."
    )
    tools = [
        {
            "name": tool_name,
            "description": f"Verbatim first/last lines for each {entry_label} entry.",
            "input_schema": ANCHOR_JSON_SCHEMA,
        }
    ]
    # Cap very large sections for the boundary pass
    clipped = section_text
    if len(clipped) > 80_000:
        clipped = clipped[:80_000]
    user = (
        f"Identify each {entry_label} entry in this section. "
        f"Return verbatim first_line and last_line for each via the {tool_name} tool.\n\n"
        f"---\n{clipped}\n---"
    )
    response = await _messages_create(
        api_key=api_key,
        system=system,
        user=user,
        tools=tools,
        tool_name=tool_name,
        max_tokens=4096,
    )
    return _tool_input(response, tool_name)


ITEM_EXTRACT_SYSTEM = (
    "You extract structured D&D 5e magic/mundane item data from source text. "
    "Extract only what is explicitly present in the text. "
    "Use null for any field that is missing or unclear. "
    "Never invent, infer, or fill gaps beyond normalizing known type/rarity labels. "
    "Normalize itemType to: armor, shield, book, scroll, equipment, potion, ring, "
    "rod, stave, wand, tool, weapon, wondrous_item "
    "(map wonderous/wondrous item → wondrous_item). "
    "Normalize rarity to: common, uncommon, rare, very_rare, legendary, artifact "
    "(very rare → very_rare). "
    "Set magic true when the entry is a magic item (wondrous, potion, ring, etc.) "
    "or the text clearly indicates magic; otherwise null if unclear. "
    "Set requiresAttunement true only if the text says requires attunement. "
    "Set consumable true for potions, scrolls, and similar one-use items when clear. "
    "Put parenthetical weapon/armor subtype (e.g. longsword) in typeReference. "
    "description should be the full body text as markdown. "
    "If the chunk is not an item entry (cover, art credit, TOC, filler), "
    "leave name/itemType/rarity/description null and briefly say so in notes. "
    "Do not put illustration credits or page decoration into unknown_fields."
)


async def extract_item(
    *,
    api_key: str,
    entry_text: str,
) -> dict[str, Any]:
    tools = [
        {
            "name": "item_extract",
            "description": "Structured item fields extracted from the source text.",
            "input_schema": ITEM_EXTRACT_JSON_SCHEMA,
        }
    ]
    user = (
        "Extract the item from the following source text into the item_extract tool.\n\n"
        f"---\n{entry_text}\n---"
    )
    response = await _messages_create(
        api_key=api_key,
        system=ITEM_EXTRACT_SYSTEM,
        user=user,
        tools=tools,
        tool_name="item_extract",
    )
    return _tool_input(response, "item_extract")


CONDITION_EXTRACT_SYSTEM = (
    "You extract structured D&D 5e condition data from source text. "
    "Extract only what is explicitly present in the text. "
    "Use null for any field that is missing or unclear. "
    "Never invent, infer, or fill gaps. "
    "name is the condition name only — strip prefixes like "
    "'New Condition:', 'Condition:', and OCR artifacts that split those "
    "prefixes across lines (e.g. 'N' then 'ew Condition: Rampaging' → Rampaging). "
    "description should be the full body text as markdown; when the source lists "
    "effects as separate sentences or bullets, format them as a markdown bullet list. "
    "Tolerate OCR noise (broken lines, doubled glyphs) when reading the name. "
    "If the chunk is not a condition entry (cover, art credit, TOC, spell, item), "
    "leave name/description null and briefly say so in notes. "
    "Do not put illustration credits or page decoration into unknown_fields."
)


async def extract_condition(
    *,
    api_key: str,
    entry_text: str,
) -> dict[str, Any]:
    tools = [
        {
            "name": "condition_extract",
            "description": "Structured condition fields extracted from the source text.",
            "input_schema": CONDITION_EXTRACT_JSON_SCHEMA,
        }
    ]
    user = (
        "Extract the condition from the following source text into the "
        "condition_extract tool.\n\n"
        f"---\n{entry_text}\n---"
    )
    response = await _messages_create(
        api_key=api_key,
        system=CONDITION_EXTRACT_SYSTEM,
        user=user,
        tools=tools,
        tool_name="condition_extract",
    )
    return _tool_input(response, "condition_extract")
