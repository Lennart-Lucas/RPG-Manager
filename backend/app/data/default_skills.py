"""Standard D&D 5e skills seeded for every user."""

from __future__ import annotations

# (name, attribute code)
DEFAULT_SKILLS: tuple[tuple[str, str], ...] = (
    ("Athletics", "STR"),
    ("Acrobatics", "DEX"),
    ("Sleight of Hand", "DEX"),
    ("Stealth", "DEX"),
    ("Arcana", "INT"),
    ("History", "INT"),
    ("Investigation", "INT"),
    ("Nature", "INT"),
    ("Religion", "INT"),
    ("Animal Handling", "WIS"),
    ("Insight", "WIS"),
    ("Medicine", "WIS"),
    ("Perception", "WIS"),
    ("Survival", "WIS"),
    ("Deception", "CHA"),
    ("Intimidation", "CHA"),
    ("Performance", "CHA"),
    ("Persuasion", "CHA"),
)
