"""Unit tests for spell AI process helpers."""

from app.services.extract.process_spell import (
    SPELL_PROCESS_SYSTEM,
    _user_message,
)
from app.services.extract.spell_schema import SPELL_PROCESS_JSON_SCHEMA


def test_spell_process_schema_requires_core_fields():
    required = set(SPELL_PROCESS_JSON_SCHEMA["required"])
    assert required == {
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
    }
    assert SPELL_PROCESS_JSON_SCHEMA["additionalProperties"] is False


def test_user_message_includes_current_and_prompt():
    msg = _user_message(
        prompt="Fill from this text",
        current={"name": "Fire Bolt", "level": 0},
        definition=None,
    )
    assert "Kind: spells" in msg
    assert "Fire Bolt" in msg
    assert "Fill from this text" in msg
    assert "Catalog definition" not in msg


def test_user_message_includes_definition():
    msg = _user_message(
        prompt="Add Wizard",
        current={"name": "Magic Missile"},
        definition={"classOptions": ["Wizard", "Sorcerer"], "tagOptions": []},
    )
    assert "Catalog definition" in msg
    assert "Wizard" in msg
    assert "Magic Missile" in msg
    assert "Add Wizard" in msg


def test_system_prompt_mentions_merge():
    assert "Merge" in SPELL_PROCESS_SYSTEM
    assert "spell_process" in SPELL_PROCESS_SYSTEM
