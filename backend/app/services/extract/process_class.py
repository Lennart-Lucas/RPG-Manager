"""Process class/subclass form data with Claude."""

from __future__ import annotations

import json
from typing import Any, Literal

from app.services.extract.class_schema import (
    CLASS_PROCESS_JSON_SCHEMA,
    SUBCLASS_PROCESS_JSON_SCHEMA,
)
from app.services.extract.claude_client import _messages_create, _tool_input

ProcessKind = Literal["classes", "subclasses"]

CLASS_PROCESS_SYSTEM = (
    "You update a D&D 5e class record for RPG Manager. "
    "You receive the current class JSON, an optional field definition, and a "
    "user prompt (source text to fill from, or instructions to rewrite). "
    "Return a complete class object via the class_process tool. "
    "Merge intelligently: keep existing values unless the prompt asks to change "
    "them or supplies better data. "
    "featuresByLevel keys are level strings \"1\"..\"20\"; each feature needs "
    "id (slug), name, level, and markdown description. "
    "Ability codes are STR/DEX/CON/INT/WIS/CHA. "
    "hitDie looks like d6/d8/d10/d12. "
    "If isCaster is false, set spellcasting to null; if true, include spellcasting "
    "with type full/half/third/pact. "
    "Do not invent empty fluff when the prompt does not ask for it; when filling "
    "from pasted class text, extract all mechanical fields and features present."
)

SUBCLASS_PROCESS_SYSTEM = (
    "You update a D&D 5e subclass record for RPG Manager. "
    "You receive the current subclass JSON, the parent class definition JSON, "
    "and a user prompt (source text or rewrite instructions). "
    "Return a complete subclass object via the subclass_process tool. "
    "Keep parentClassId unchanged unless the prompt explicitly requires it. "
    "Respect the parent class subclassChosenAtLevel: feature levels should be "
    "at or above that level when possible. "
    "featuresByLevel keys are level strings; each feature needs id, name, level, "
    "and markdown description. "
    "Merge intelligently: preserve existing fields unless the prompt changes them "
    "or supplies better data from pasted subclass text."
)


def _user_message(
    *,
    kind: ProcessKind,
    prompt: str,
    current: dict[str, Any],
    definition: dict[str, Any] | None,
) -> str:
    parts = [
        f"Kind: {kind}",
        "Current record JSON:",
        json.dumps(current, ensure_ascii=False, indent=2),
    ]
    if definition:
        parts.extend(
            [
                "",
                "Parent class / definition JSON:",
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


async def process_class_record(
    *,
    api_key: str,
    kind: ProcessKind,
    prompt: str,
    current: dict[str, Any],
    definition: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if kind == "subclasses":
        tool_name = "subclass_process"
        schema = SUBCLASS_PROCESS_JSON_SCHEMA
        system = SUBCLASS_PROCESS_SYSTEM
        description = "Complete updated subclass record."
    else:
        tool_name = "class_process"
        schema = CLASS_PROCESS_JSON_SCHEMA
        system = CLASS_PROCESS_SYSTEM
        description = "Complete updated class record."

    tools = [
        {
            "name": tool_name,
            "description": description,
            "input_schema": schema,
        }
    ]
    response = await _messages_create(
        api_key=api_key,
        system=system,
        user=_user_message(
            kind=kind,
            prompt=prompt,
            current=current,
            definition=definition,
        ),
        tools=tools,
        tool_name=tool_name,
        max_tokens=8192,
    )
    return _tool_input(response, tool_name)
