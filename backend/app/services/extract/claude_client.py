from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from app.config import settings
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
                    detail = msg[:200]
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
    "If the text contains information that does not map to the schema, "
    "put a short summary in notes and/or key-value pairs in unknown_fields. "
    "Class and tag names should be plain strings as written in the source."
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


ANCHOR_SYSTEM = (
    "You identify individual spell entry boundaries in RPG source text. "
    "For each spell entry, quote the exact first line and exact last line "
    "verbatim from the source — do not paraphrase or normalize punctuation. "
    "Only include entries you can ground in the text."
)


async def detect_anchors(
    *,
    api_key: str,
    section_text: str,
) -> dict[str, Any]:
    tools = [
        {
            "name": "spell_anchors",
            "description": "Verbatim first/last lines for each spell entry.",
            "input_schema": ANCHOR_JSON_SCHEMA,
        }
    ]
    # Cap very large sections for the boundary pass
    clipped = section_text
    if len(clipped) > 80_000:
        clipped = clipped[:80_000]
    user = (
        "Identify each spell entry in this section. "
        "Return verbatim first_line and last_line for each via the spell_anchors tool.\n\n"
        f"---\n{clipped}\n---"
    )
    response = await _messages_create(
        api_key=api_key,
        system=ANCHOR_SYSTEM,
        user=user,
        tools=tools,
        tool_name="spell_anchors",
        max_tokens=4096,
    )
    return _tool_input(response, "spell_anchors")
