from app.services.extract.item_schema import (
    ItemExtractPayload,
    normalize_item_rarity,
    normalize_item_type,
)
from app.services.extract.tier1_split import (
    health_check_section,
    looks_like_item_chunk,
    looks_like_spell_chunk,
    split_document,
)
from app.services.extract.tier2_anchors import verify_anchor_pair


SAMPLE_SPELL_LIST = """
Spells

Fire Bolt
Evocation cantrip
Casting Time: 1 action
Range: 120 feet
Components: V, S
Duration: Instantaneous
You hurl a mote of fire at a creature or object within range.

Magic Missile
1st-level evocation
Casting Time: 1 action
Range: 120 feet
Components: V, S
Duration: Instantaneous
You create three glowing darts of magical force.

Shield
1st-level abjuration
Casting Time: 1 reaction, which you take when you are hit by an attack
Range: Self
Components: V, S
Duration: 1 round
An invisible barrier of magical force appears and protects you.

Misty Step
2nd-level conjuration
Casting Time: 1 bonus action
Range: Self
Components: V
Duration: Instantaneous
Briefly surrounded by silvery mist, you teleport up to 30 feet.
"""


def test_tier1_splits_clean_spell_list():
    result = split_document(SAMPLE_SPELL_LIST)
    assert len(result.sections) >= 1
    section = result.sections[0]
    assert section.health_ok, section.health_reasons
    assert len(section.entries) == 4
    names = [e.name_hint for e in section.entries]
    assert names[0] and "Fire Bolt" in names[0]
    assert any(e.name_hint and "Shield" in e.name_hint for e in section.entries)


def test_health_check_rejects_tiny_section():
    from app.services.extract.tier1_split import SplitEntry

    entries = [
        SplitEntry(text="a" * 100, name_hint="A"),
        SplitEntry(text="b" * 100, name_hint="B"),
    ]
    ok, reasons = health_check_section(entries, "")
    assert not ok
    assert any(r.startswith("implausible_entry_count") for r in reasons)


def test_health_check_rejects_length_outlier():
    from app.services.extract.tier1_split import SplitEntry

    entries = [
        SplitEntry(text="x" * 100, name_hint="A"),
        SplitEntry(text="y" * 100, name_hint="B"),
        SplitEntry(text="z" * 100, name_hint="C"),
        SplitEntry(text="w" * 5000, name_hint="D"),
    ]
    ok, reasons = health_check_section(entries, "")
    assert not ok
    assert "entry_length_outlier" in reasons


def test_verify_anchor_pair_success():
    source = "Alpha Spell\nLine two\nLine three\nEnd here\nNext"
    span = verify_anchor_pair(source, "Alpha Spell", "End here")
    assert span.verified
    assert span.entry_text is not None
    assert "Alpha Spell" in span.entry_text
    assert "End here" in span.entry_text


def test_verify_anchor_pair_failure():
    source = "Alpha Spell\nLine two"
    span = verify_anchor_pair(source, "Alpha Spell", "Not present")
    assert not span.verified


def test_looks_like_spell_chunk_accepts_meta():
    text = "Fire Bolt\nCasting Time: 1 action\nRange: 120 feet"
    assert looks_like_spell_chunk(text)


def test_looks_like_spell_chunk_accepts_school_level():
    text = "Magic Missile\n1st-level evocation\nYou create darts."
    assert looks_like_spell_chunk(text)


def test_looks_like_spell_chunk_rejects_cover():
    text = "RIGHTEOUS SPELLS\nWrath & Ruin\nConcept Art\nby Jun Kim"
    assert not looks_like_spell_chunk(text)


SAMPLE_ITEM_LIST = """
Magic Items

Cloak of Darkness
Wonderous item, very rare
This cloak shrouds the wearer in perpetual shadow.
While wearing it, you can cast darkness once per day.

Ring of Protection
Ring, rare (requires attunement)
You gain a +1 bonus to AC and saving throws while wearing this ring.

Potion of Healing
Potion, common
You regain 2d4 + 2 hit points when you drink this potion.
"""


def test_tier1_splits_item_list():
    result = split_document(SAMPLE_ITEM_LIST, kind="items")
    assert len(result.sections) >= 1
    section = result.sections[0]
    assert section.health_ok, section.health_reasons
    assert len(section.entries) == 3
    names = [e.name_hint for e in section.entries]
    assert names[0] and "Cloak of Darkness" in names[0]
    assert any(e.name_hint and "Ring of Protection" in e.name_hint for e in section.entries)


def test_looks_like_item_chunk_accepts_type_rarity():
    text = (
        "Cloak of Darkness\n"
        "Wonderous item, very rare\n"
        "This cloak shrouds the wearer in shadow."
    )
    assert looks_like_item_chunk(text)


def test_looks_like_item_chunk_accepts_attunement():
    text = (
        "Ring of Protection\n"
        "Ring, rare (requires attunement)\n"
        "You gain a +1 bonus to AC."
    )
    assert looks_like_item_chunk(text)


def test_looks_like_item_chunk_rejects_cover():
    text = "MAGIC ITEMS\nWrath & Ruin\nConcept Art\nby Jun Kim"
    assert not looks_like_item_chunk(text)


def test_normalize_wonderous_and_very_rare():
    assert normalize_item_type("Wonderous item") == "wondrous_item"
    assert normalize_item_type("wondrous item") == "wondrous_item"
    assert normalize_item_rarity("very rare") == "very_rare"
    payload = ItemExtractPayload.model_validate(
        {
            "name": "Cloak of Darkness",
            "itemType": "Wonderous item",
            "rarity": "very rare",
            "magic": True,
            "requiresAttunement": False,
            "consumable": False,
            "typeReference": None,
            "description": "Shrouds the wearer.",
            "sourcePage": 12,
            "notes": None,
            "unknown_fields": None,
        }
    )
    assert payload.itemType == "wondrous_item"
    assert payload.rarity == "very_rare"


def test_looks_like_item_chunk_accepts_price_suffix():
    text = (
        "Hex-Stone Amulet\n"
        "Wondrous Item, Very Rare (Requires Attunement), 36,000 gp\n"
        "This pendant emits a sickly green light."
    )
    assert looks_like_item_chunk(text)


def test_looks_like_item_chunk_accepts_price_before_rarity():
    text = (
        "Oil of Explosive Speed\n"
        "Potion, 50gp, uncommon, weight: 1 lb\n"
        "This vial contains volatile eldritch oil."
    )
    assert looks_like_item_chunk(text)


def test_looks_like_item_chunk_accepts_wonderous_with_price():
    text = (
        "Hex Stone Token\n"
        "Wonderous Item, Rare, 200g\n"
        "These palm-size wafers boost magical abilities."
    )
    assert looks_like_item_chunk(text)


def test_collapse_doubled_pdf_glyphs():
    from app.services.extract.tier1_split import collapse_doubled_pdf_glyphs

    assert "Cloak of Darkness" in collapse_doubled_pdf_glyphs(
        "CCllooaakk ooff DDaarrkknneessss\nWonderous item, very rare\n"
    )


def test_tier1_splits_priced_item_headers():
    sample = """
Magic Items

Hex-Stone Amulet
Wondrous Item, Very Rare (Requires Attunement), 36,000 gp
This pendant emits a sickly green light.

Gnawfang
Weapon (Dagger), Very Rare (Requires Attunement), 2,000 gp
Carved from a sliver of the Rat God's fang.

Hex Stone Token
Wonderous Item, Rare, 200g
These palm-size wafers of magical minerals can be consumed.
"""
    result = split_document(sample, kind="items")
    section = result.sections[0]
    assert section.health_ok, section.health_reasons
    assert len(section.entries) == 3
    assert any(
        e.name_hint and "Hex-Stone" in e.name_hint for e in section.entries
    )
