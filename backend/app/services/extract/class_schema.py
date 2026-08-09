"""JSON Schema for Claude tool_use when processing class records."""

from __future__ import annotations

from typing import Any

_FEATURE = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "id": {"type": "string"},
        "name": {"type": "string"},
        "level": {"type": "integer", "minimum": 1, "maximum": 20},
        "description": {"type": "string"},
    },
    "required": ["id", "name", "level", "description"],
}

_SPELL_SLOT_TABLE = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "cantripsKnown": {"type": "integer", "minimum": 0},
        "spellsKnownOrPrepared": {"type": "integer", "minimum": 0},
        "slotsByCircle": {
            "type": "array",
            "items": {"type": "integer", "minimum": 0},
        },
    },
    "required": ["cantripsKnown", "spellsKnownOrPrepared", "slotsByCircle"],
}

_SPELLCASTING = {
    "type": ["object", "null"],
    "additionalProperties": False,
    "properties": {
        "ability": {
            "type": "string",
            "enum": ["STR", "DEX", "CON", "INT", "WIS", "CHA"],
        },
        "type": {
            "type": "string",
            "enum": ["full", "half", "third", "pact", "none"],
        },
        "slotsByLevel": {
            "type": "object",
            "additionalProperties": _SPELL_SLOT_TABLE,
        },
        "preparesSpells": {"type": "boolean"},
    },
    "required": ["ability", "type", "slotsByLevel", "preparesSpells"],
}

CLASS_PROCESS_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "name": {"type": "string"},
        "description": {"type": "string"},
        "isCaster": {"type": "boolean"},
        "hitDie": {"type": "string"},
        "primaryAbilities": {
            "type": "array",
            "items": {
                "type": "string",
                "enum": ["STR", "DEX", "CON", "INT", "WIS", "CHA"],
            },
        },
        "savingThrowProficiencies": {
            "type": "array",
            "items": {
                "type": "string",
                "enum": ["STR", "DEX", "CON", "INT", "WIS", "CHA"],
            },
        },
        "armorProficiencies": {"type": "array", "items": {"type": "string"}},
        "weaponProficiencies": {"type": "array", "items": {"type": "string"}},
        "toolProficiencies": {"type": "array", "items": {"type": "string"}},
        "skillChoiceCount": {"type": "integer", "minimum": 0, "maximum": 20},
        "skillChoices": {"type": "array", "items": {"type": "string"}},
        "featuresByLevel": {
            "type": "object",
            "additionalProperties": {
                "type": "array",
                "items": _FEATURE,
            },
        },
        "subclassChosenAtLevel": {
            "type": "integer",
            "minimum": 1,
            "maximum": 20,
        },
        "spellcasting": _SPELLCASTING,
    },
    "required": [
        "name",
        "description",
        "isCaster",
        "hitDie",
        "primaryAbilities",
        "savingThrowProficiencies",
        "armorProficiencies",
        "weaponProficiencies",
        "toolProficiencies",
        "skillChoiceCount",
        "skillChoices",
        "featuresByLevel",
        "subclassChosenAtLevel",
        "spellcasting",
    ],
}

SUBCLASS_PROCESS_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "name": {"type": "string"},
        "parentClassId": {"type": "integer"},
        "description": {"type": "string"},
        "featuresByLevel": {
            "type": "object",
            "additionalProperties": {
                "type": "array",
                "items": _FEATURE,
            },
        },
    },
    "required": ["name", "parentClassId", "description", "featuresByLevel"],
}
