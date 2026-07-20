from app.services.extract.tier1_split import health_check_section, split_document
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
