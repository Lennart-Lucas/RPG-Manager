"""Unit tests for catalog markdown search snippets."""

from app.services.catalog_search_text import (
    markdown_snippet_for_query,
    name_matches_query,
)


def test_name_matches_query_case_insensitive():
    assert name_matches_query("Fireball", "fire")
    assert not name_matches_query("Magic Missile", "fire")


def test_snippet_from_description_when_name_does_not_match():
    payload = {
        "description": (
            "A glowing crystal that hums with arcane energy whenever "
            "the bearer speaks the secret passphrase."
        ),
    }
    snippet = markdown_snippet_for_query(payload, "passphrase")
    assert snippet is not None
    assert "passphrase" in snippet.casefold()
    # Name-only style: no snippet when caller would skip (name match).
    assert name_matches_query("Secret Passphrase Stone", "passphrase")


def test_snippet_null_when_query_absent_from_markdown():
    payload = {"description": "Nothing interesting here.", "imageUrl": "/x"}
    assert markdown_snippet_for_query(payload, "passphrase") is None


def test_snippet_from_overview_sections():
    payload = {
        "overviewSections": [
            {
                "title": "Details",
                "items": [
                    {
                        "label": "Note",
                        "description": "Home of the whispered covenant.",
                    }
                ],
            }
        ],
    }
    snippet = markdown_snippet_for_query(payload, "covenant")
    assert snippet is not None
    assert "covenant" in snippet.casefold()


def test_snippet_strips_wiki_links_and_truncates():
    payload = {
        "description": (
            "See [[locations/42|the old keep]] near the river where "
            "ancient **runes** still glow at midnight under the moon."
        ),
    }
    snippet = markdown_snippet_for_query(payload, "runes")
    assert snippet is not None
    assert "runes" in snippet.casefold()
    assert "[[" not in snippet
    assert "**" not in snippet


def test_content_hit_vs_name_only_policy():
    """Document the search hit policy used by search_items."""
    q = "arcane"
    name_only = "Arcane Bolt"
    content_only_name = "Glowing Crystal"
    content_payload = {
        "description": "Infused with arcane residue from the last war.",
    }

    # Name match → no snippet needed.
    assert name_matches_query(name_only, q)
    # Content match → snippet present.
    assert not name_matches_query(content_only_name, q)
    snippet = markdown_snippet_for_query(content_payload, q)
    assert snippet is not None
    assert "arcane" in snippet.casefold()
