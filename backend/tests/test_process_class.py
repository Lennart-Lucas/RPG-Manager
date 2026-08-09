"""Unit tests for class/subclass AI process helpers."""

from app.services.extract.class_schema import (
    CLASS_PROCESS_JSON_SCHEMA,
    SUBCLASS_PROCESS_JSON_SCHEMA,
)
from app.services.extract.process_class import (
    CLASS_PROCESS_SYSTEM,
    SUBCLASS_PROCESS_SYSTEM,
    _user_message,
)


def test_class_schema_requires_core_fields():
    required = set(CLASS_PROCESS_JSON_SCHEMA["required"])
    assert "name" in required
    assert "featuresByLevel" in required
    assert "spellcasting" in required


def test_subclass_schema_requires_parent_and_features():
    required = set(SUBCLASS_PROCESS_JSON_SCHEMA["required"])
    assert required == {"name", "parentClassId", "description", "featuresByLevel"}


def test_user_message_includes_current_and_prompt():
    msg = _user_message(
        kind="classes",
        prompt="Fill from this text",
        current={"name": "Fighter", "description": ""},
        definition=None,
    )
    assert "Kind: classes" in msg
    assert "Fighter" in msg
    assert "Fill from this text" in msg
    assert "Parent class" not in msg


def test_user_message_includes_definition_for_subclass():
    msg = _user_message(
        kind="subclasses",
        prompt="Add features",
        current={"name": "Champion", "parentClassId": 3},
        definition={"name": "Fighter", "subclassChosenAtLevel": 3},
    )
    assert "Kind: subclasses" in msg
    assert "Champion" in msg
    assert "subclassChosenAtLevel" in msg
    assert "Add features" in msg


def test_system_prompts_mention_merge():
    assert "Merge" in CLASS_PROCESS_SYSTEM
    assert "parentClassId" in SUBCLASS_PROCESS_SYSTEM
