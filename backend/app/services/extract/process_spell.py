"""Process spell form data with Claude."""

from __future__ import annotations

import json
from typing import Any

from app.services.extract.claude_client import _messages_create, _tool_input
from app.services.extract.spell_schema import SPELL_PROCESS_JSON_SCHEMA

SPELL_PROCESS_SYSTEM = (
    "You update a D&D 5e spell record for RPG Manager. "
    "You receive the current spell JSON, optional catalog definition "
    "(allowed class and tag names), and a user prompt (source text to fill "
    "from, or instructions to rewrite). "
    "Return a complete spell object via the spell_process tool. "
    "Merge intelligently: keep existing values unless the prompt asks to change "
    "them or supplies better data. "
    "classes and tags are display names from the definition lists when possible; "
    "prefer exact matches from classOptions / tagOptions. "
    "school must be one of the eight 5e schools (lowercase). "
    "range.type is self, touch, or ranged; set distanceFeet only for ranged. "
    "higherLevels is plain text for At Higher Levels (empty string if none). "
    "description and higherLevels may use markdown. "
    "Do not invent empty fluff when the prompt does not ask for it; when filling "
    "from pasted spell text, extract all mechanical fields present."
)


def _user_message(
    *,
    prompt: str,
    current: dict[str, Any],
    definition: dict[str, Any] | None,
) -> str:
    parts = [
        "Kind: spells",
        "Current record JSON:",
        json.dumps(current, ensure_ascii=False, indent=2),
    ]
    if definition:
        parts.extend(
            [
                "",
                "Catalog definition JSON (allowed class/tag names):",
                json.dumps(definition, ensure_ascii=False, indent=2),
            ]
        )
    parts.extend(
        [
            "",
            "User prompt / source text:",
            "---",
            prompt,
            "---",
            "",
            "Return the full updated record via the tool.",
        ]
    )
    return "\n".join(parts)


async def process_spell_record(
    *,
    api_key: str,
    prompt: str,
    current: dict[str, Any],
    definition: dict[str, Any] | None = None,
) -> dict[str, Any]:
    tool_name = "spell_process"
    tools = [
        {
            "name": tool_name,
            "description": "Complete updated spell record.",
            "input_schema": SPELL_PROCESS_JSON_SCHEMA,
        }
    ]
    response = await _messages_create(
        api_key=api_key,
        system=SPELL_PROCESS_SYSTEM,
        user=_user_message(
            prompt=prompt,
            current=current,
            definition=definition,
        ),
        tools=tools,
        tool_name=tool_name,
        max_tokens=8192,
    )
    return _tool_input(response, tool_name)
