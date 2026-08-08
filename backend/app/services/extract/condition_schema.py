from __future__ import annotations

from typing import Any

from pydantic import BaseModel, field_validator


class ConditionExtractPayload(BaseModel):
    """Strict condition fields extracted from source text (null = missing)."""

    name: str | None = None
    description: str | None = None
    sourcePage: int | None = None
    notes: str | None = None
    unknown_fields: dict[str, Any] | None = None

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        # Strip common PDF prefixes: "New Condition: Rampaging" → "Rampaging"
        lowered = stripped.casefold()
        for prefix in (
            "new condition:",
            "condition:",
            "new condition",
        ):
            if lowered.startswith(prefix):
                rest = stripped[len(prefix) :].strip(" :\t-")
                return rest or None
        return stripped or None

    @field_validator("description")
    @classmethod
    def strip_description(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


CONDITION_EXTRACT_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "name": {"type": ["string", "null"]},
        "description": {"type": ["string", "null"]},
        "sourcePage": {"type": ["integer", "null"]},
        "notes": {"type": ["string", "null"]},
        "unknown_fields": {
            "type": ["object", "null"],
            "additionalProperties": True,
        },
    },
    "required": [
        "name",
        "description",
        "sourcePage",
        "notes",
        "unknown_fields",
    ],
}
