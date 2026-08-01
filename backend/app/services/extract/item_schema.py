from __future__ import annotations

from typing import Any

from pydantic import BaseModel, field_validator


ITEM_TYPES = (
    "armor",
    "shield",
    "book",
    "scroll",
    "equipment",
    "potion",
    "ring",
    "rod",
    "stave",
    "wand",
    "tool",
    "weapon",
    "wondrous_item",
)

ITEM_RARITIES = (
    "common",
    "uncommon",
    "rare",
    "very_rare",
    "legendary",
    "artifact",
    "variable",
)

_ITEM_TYPE_ALIASES: dict[str, str] = {
    "armor": "armor",
    "armour": "armor",
    "shield": "shield",
    "book": "book",
    "scroll": "scroll",
    "equipment": "equipment",
    "potion": "potion",
    "ring": "ring",
    "rod": "rod",
    "stave": "stave",
    "staff": "stave",
    "wand": "wand",
    "tool": "tool",
    "weapon": "weapon",
    "wondrous_item": "wondrous_item",
    "wondrous item": "wondrous_item",
    "wondrous": "wondrous_item",
    "wonderous item": "wondrous_item",
    "wonderous": "wondrous_item",
}

_RARITY_ALIASES: dict[str, str] = {
    "common": "common",
    "uncommon": "uncommon",
    "rare": "rare",
    "very rare": "very_rare",
    "very_rare": "very_rare",
    "legendary": "legendary",
    "ledgendary": "legendary",
    "artifact": "artifact",
    "variable": "variable",
    "varies": "variable",
}


def normalize_item_type(value: str | None) -> str | None:
    if value is None:
        return None
    key = value.strip().lower().replace("_", " ")
    key = " ".join(key.split())
    mapped = _ITEM_TYPE_ALIASES.get(key)
    if mapped is not None:
        return mapped
    # "Weapon (longsword)" → weapon
    base = key.split("(", 1)[0].strip()
    if base.endswith(" item"):
        base = base[: -len(" item")].strip()
    return _ITEM_TYPE_ALIASES.get(base)


def normalize_item_rarity(value: str | None) -> str | None:
    if value is None:
        return None
    key = value.strip().lower().replace("_", " ")
    key = " ".join(key.split())
    return _RARITY_ALIASES.get(key)


class ItemExtractPayload(BaseModel):
    """Strict item fields extracted from source text (null = missing)."""

    name: str | None = None
    itemType: str | None = None
    rarity: str | None = None
    magic: bool | None = None
    requiresAttunement: bool | None = None
    consumable: bool | None = None
    typeReference: str | None = None
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
        return stripped or None

    @field_validator("itemType")
    @classmethod
    def normalize_type(cls, value: str | None) -> str | None:
        if value is None:
            return None
        mapped = normalize_item_type(value)
        if mapped is None:
            raise ValueError(f"Unknown itemType: {value}")
        return mapped

    @field_validator("rarity")
    @classmethod
    def normalize_rarity(cls, value: str | None) -> str | None:
        if value is None:
            return None
        mapped = normalize_item_rarity(value)
        if mapped is None:
            raise ValueError(f"Unknown rarity: {value}")
        return mapped

    @field_validator("typeReference")
    @classmethod
    def strip_type_reference(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


ITEM_EXTRACT_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "name": {"type": ["string", "null"]},
        "itemType": {
            "type": ["string", "null"],
            "enum": list(ITEM_TYPES),
        },
        "rarity": {
            "type": ["string", "null"],
            "enum": list(ITEM_RARITIES),
        },
        "magic": {"type": ["boolean", "null"]},
        "requiresAttunement": {"type": ["boolean", "null"]},
        "consumable": {"type": ["boolean", "null"]},
        "typeReference": {"type": ["string", "null"]},
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
        "itemType",
        "rarity",
        "magic",
        "requiresAttunement",
        "consumable",
        "typeReference",
        "description",
        "sourcePage",
        "notes",
        "unknown_fields",
    ],
}
