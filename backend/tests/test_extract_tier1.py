from app.services.extract.condition_schema import ConditionExtractPayload
from app.services.extract.item_schema import (
    ItemExtractPayload,
    normalize_item_rarity,
    normalize_item_type,
)
from app.services.extract.tier1_split import (
    health_check_section,
    looks_like_condition_chunk,
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


def test_health_check_allows_large_leftover_with_entries():
    from app.services.extract.tier1_split import SplitEntry, health_check_section

    entries = [
        SplitEntry(text="x" * 100, name_hint="A"),
        SplitEntry(text="y" * 100, name_hint="B"),
        SplitEntry(text="z" * 100, name_hint="C"),
    ]
    ok, reasons = health_check_section(entries, "L" * 500)
    assert ok
    assert "large_leftover_text" in reasons


def test_item_entry_start_requires_type_peek():
    from app.services.extract.tier1_split import split_document

    # Spell-shaped Title Case lines must not become item entries
    text = """
Some Chapter

Ray of Sickness
1st-level necromancy
Casting Time: 1 action
Range: 60 feet

Cloak of Darkness
Wonderous item, very rare
Hidden in shadow.

Ring of Protection
Ring, rare (requires attunement)
Bonus to AC.

Potion of Healing
Potion, common
Regain hit points.
"""
    result = split_document(text, kind="items")
    names = [
        e.name_hint
        for s in result.sections
        for e in s.entries
        if e.name_hint
    ]
    assert not any(n and "Ray of Sickness" in n for n in names)
    assert any(n and "Cloak of Darkness" in n for n in names)
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


SAMPLE_CONDITION_LIST = """
Conditions

Blinded
A blinded creature can't see and automatically fails any ability check that requires sight.
Attack rolls against the creature have advantage, and the creature's attack rolls have disadvantage.

Frightened
A frightened creature has disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.
The creature can't willingly move closer to the source of its fear.

Poisoned
A poisoned creature has disadvantage on attack rolls and ability checks.

Restrained
A restrained creature's speed becomes 0, and it can't benefit from any bonus to its speed.
Attack rolls against the creature have advantage, and the creature's attack rolls have disadvantage.
The creature has disadvantage on Dexterity saving throws.
"""


def test_tier1_splits_condition_list():
    result = split_document(SAMPLE_CONDITION_LIST, kind="conditions")
    assert len(result.sections) >= 1
    section = result.sections[0]
    assert section.health_ok, section.health_reasons
    assert len(section.entries) == 4
    names = [e.name_hint for e in section.entries]
    assert names[0] and "Blinded" in names[0]
    assert any(e.name_hint and "Frightened" in e.name_hint for e in section.entries)
    assert any(e.name_hint and "Restrained" in e.name_hint for e in section.entries)


def test_tier1_splits_new_condition_headers():
    text = """
New Conditions

New Condition: Rampaging
The creature loses its free will as it enters a mindless Rampage.
Any Charmed or Frightened effects on the creature are suspended.
The creature can't cast spells or maintain Concentration.
On each of its turns, the creature must take the Attack action against the nearest hostile creature.

New Condition: Marked
A marked creature can't hide from the one who marked it.
Attack rolls against the marked creature have advantage.
The creature must succeed on a Wisdom saving throw to move away.

New Condition: Anchored
An anchored creature's speed becomes 0.
The creature can't teleport or otherwise leave its space by magical means.
"""
    result = split_document(text, kind="conditions")
    section = result.sections[0]
    assert section.health_ok, section.health_reasons
    assert len(section.entries) == 3
    names = [e.name_hint for e in section.entries]
    assert any(n and "Rampaging" in n for n in names)
    assert any(n and "Marked" in n for n in names)
    assert any(n and "Anchored" in n for n in names)


def test_tier1_splits_ocr_broken_new_condition():
    text = """
Conditions

N
ew Condition: Rampaging
The creature loses its free will as it enters a mindless Rampage.
Any Charmed or Frightened effects on the creature are suspended.
The creature can't cast spells or maintain Concentration on spells or other effects.
On each of its turns, the creature must take the Attack action against the nearest hostile creature it can see within range.

Blinded
A blinded creature can't see and automatically fails any ability check that requires sight.
Attack rolls against the creature have advantage.

Frightened
A frightened creature has disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.
The creature can't willingly move closer to the source of its fear.
"""
    result = split_document(text, kind="conditions")
    section = result.sections[0]
    assert len(section.entries) >= 3
    names = [e.name_hint for e in section.entries]
    assert any(n and "Rampaging" in n for n in names)
    rampaging = next(e for e in section.entries if e.name_hint and "Rampaging" in e.name_hint)
    assert looks_like_condition_chunk(rampaging.text)


def test_looks_like_condition_chunk_accepts_effects():
    text = (
        "Blinded\n"
        "A blinded creature can't see and automatically fails any ability check "
        "that requires sight. Attack rolls against the creature have advantage."
    )
    assert looks_like_condition_chunk(text)


def test_looks_like_condition_chunk_accepts_new_condition_header():
    text = (
        "New Condition: Rampaging\n"
        "The creature loses its free will as it enters a mindless Rampage. "
        "The creature can't cast spells. On each of its turns, the creature "
        "must take the Attack action against the nearest hostile creature."
    )
    assert looks_like_condition_chunk(text)


def test_looks_like_condition_chunk_rejects_spell():
    text = "Fire Bolt\nEvocation cantrip\nCasting Time: 1 action\nRange: 120 feet"
    assert not looks_like_condition_chunk(text)
    assert looks_like_spell_chunk(text)


def test_looks_like_condition_chunk_rejects_item():
    text = (
        "Cloak of Darkness\n"
        "Wonderous item, very rare\n"
        "This cloak shrouds the wearer in shadow."
    )
    assert not looks_like_condition_chunk(text)
    assert looks_like_item_chunk(text)


def test_condition_payload_strips_new_condition_prefix():
    payload = ConditionExtractPayload.model_validate(
        {
            "name": "New Condition: Rampaging",
            "description": "The creature must Attack.",
            "sourcePage": 10,
            "notes": None,
            "unknown_fields": None,
        }
    )
    assert payload.name == "Rampaging"
