"""Unit tests for id-based wiki link helpers."""

from app.services.catalog_wiki import (
    extract_wiki_refs,
    rewrite_wiki_targets_to_ids,
)


def test_extract_wiki_refs_reads_ids_and_names():
    text = "A [[conditions/42]] and ![[damage_types/Fire|Fire]]"
    assert extract_wiki_refs(text) == [
        ("conditions", "42"),
        ("damage_types", "Fire"),
    ]


def test_rewrite_wiki_targets_to_ids():
    text = "See [[conditions/Invisible]] and [[conditions/42]] and ![[damage_types/Fire|Burn]]"
    resolve = {
        ("conditions", "invisible"): 42,
        ("damage_types", "fire"): 7,
    }
    out = rewrite_wiki_targets_to_ids(text, resolve=resolve)
    assert out == (
        "See [[conditions/42]] and [[conditions/42]] and ![[damage_types/7|Burn]]"
    )
