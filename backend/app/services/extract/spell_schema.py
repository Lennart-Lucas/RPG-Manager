from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class CastingTimeExtract(BaseModel):
    amount: int | None = Field(default=None, ge=1)
    unit: Literal["action", "bonus action", "reaction", "minute", "hour"] | None = (
        None
    )
    reactionTrigger: str | None = None


class RangeExtract(BaseModel):
    type: Literal["self", "touch", "ranged"] | None = None
    distanceFeet: int | None = None


class ComponentsExtract(BaseModel):
    verbal: bool | None = None
    somatic: bool | None = None
    material: bool | None = None
    materialDescription: str | None = None
    materialCostGp: float | None = None
    materialConsumed: bool | None = None


class DurationExtract(BaseModel):
    type: (
        Literal[
            "instantaneous",
            "oneRound",
            "oneMinute",
            "tenMinutes",
            "oneHour",
            "eightHours",
            "twentyFourHours",
            "oneDay",
            "sevenDays",
            "tenDays",
            "thirtyDays",
            "untilDispelled",
            "untilDispelledOrTriggered",
            "special",
        ]
        | None
    ) = None
    concentration: bool | None = None
    special: str | None = None


SPELL_SCHOOLS = (
    "abjuration",
    "conjuration",
    "divination",
    "enchantment",
    "evocation",
    "illusion",
    "necromancy",
    "transmutation",
)


class SpellExtractPayload(BaseModel):
    """Strict spell fields extracted from source text (null = missing)."""

    name: str | None = None
    level: int | None = Field(default=None, ge=0, le=9)
    school: str | None = None
    castingTime: CastingTimeExtract | None = None
    range: RangeExtract | None = None
    components: ComponentsExtract | None = None
    duration: DurationExtract | None = None
    classes: list[str] | None = None
    tags: list[str] | None = None
    description: str | None = None
    higherLevels: str | None = None
    sourcePage: int | None = None
    notes: str | None = None
    unknown_fields: dict[str, Any] | None = None

    @field_validator("school")
    @classmethod
    def normalize_school(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip().lower()
        if normalized not in SPELL_SCHOOLS:
            raise ValueError(f"Unknown school: {value}")
        return normalized

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


SPELL_EXTRACT_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "name": {"type": ["string", "null"]},
        "level": {"type": ["integer", "null"], "minimum": 0, "maximum": 9},
        "school": {
            "type": ["string", "null"],
            "enum": list(SPELL_SCHOOLS),
        },
        "castingTime": {
            "type": ["object", "null"],
            "additionalProperties": False,
            "properties": {
                "amount": {"type": ["integer", "null"], "minimum": 1},
                "unit": {
                    "type": ["string", "null"],
                    "enum": [
                        "action",
                        "bonus action",
                        "reaction",
                        "minute",
                        "hour",
                    ],
                },
                "reactionTrigger": {"type": ["string", "null"]},
            },
            "required": ["amount", "unit", "reactionTrigger"],
        },
        "range": {
            "type": ["object", "null"],
            "additionalProperties": False,
            "properties": {
                "type": {
                    "type": ["string", "null"],
                    "enum": ["self", "touch", "ranged"],
                },
                "distanceFeet": {"type": ["integer", "null"]},
            },
            "required": ["type", "distanceFeet"],
        },
        "components": {
            "type": ["object", "null"],
            "additionalProperties": False,
            "properties": {
                "verbal": {"type": ["boolean", "null"]},
                "somatic": {"type": ["boolean", "null"]},
                "material": {"type": ["boolean", "null"]},
                "materialDescription": {"type": ["string", "null"]},
                "materialCostGp": {"type": ["number", "null"]},
                "materialConsumed": {"type": ["boolean", "null"]},
            },
            "required": [
                "verbal",
                "somatic",
                "material",
                "materialDescription",
                "materialCostGp",
                "materialConsumed",
            ],
        },
        "duration": {
            "type": ["object", "null"],
            "additionalProperties": False,
            "properties": {
                "type": {
                    "type": ["string", "null"],
                    "enum": [
                        "instantaneous",
                        "oneRound",
                        "oneMinute",
                        "tenMinutes",
                        "oneHour",
                        "eightHours",
                        "twentyFourHours",
                        "oneDay",
                        "sevenDays",
                        "tenDays",
                        "thirtyDays",
                        "untilDispelled",
                        "untilDispelledOrTriggered",
                        "special",
                    ],
                },
                "concentration": {"type": ["boolean", "null"]},
                "special": {"type": ["string", "null"]},
            },
            "required": ["type", "concentration", "special"],
        },
        "classes": {
            "type": ["array", "null"],
            "items": {"type": "string"},
        },
        "tags": {
            "type": ["array", "null"],
            "items": {"type": "string"},
        },
        "description": {"type": ["string", "null"]},
        "higherLevels": {"type": ["string", "null"]},
        "sourcePage": {"type": ["integer", "null"]},
        "notes": {"type": ["string", "null"]},
        "unknown_fields": {
            "type": ["object", "null"],
            "additionalProperties": True,
        },
    },
    "required": [
        "name",
        "level",
        "school",
        "castingTime",
        "range",
        "components",
        "duration",
        "classes",
        "tags",
        "description",
        "higherLevels",
        "sourcePage",
        "notes",
        "unknown_fields",
    ],
}
