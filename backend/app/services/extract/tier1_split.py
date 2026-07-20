from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any


PAGE_MARKER_RE = re.compile(r"(?m)^---\s*page\s+(\d+)\s*---\s*$")

# Common RPG section headers for spell lists
SECTION_HEADER_RE = re.compile(
    r"(?im)^\s*(?:"
    r"spells?|"
    r"cantrips?|"
    r"\d+(?:st|nd|rd|th)[\-\s]?level(?:\s+spells?)?|"
    r"spell\s+descriptions?"
    r")\s*$"
)

# Entry start: Title Case / ALL CAPS name on its own line, optionally with level tag
ENTRY_START_RE = re.compile(
    r"(?m)^(?P<name>[A-Z][A-Za-z0-9'’\-\s]{1,60}?)(?:\s*\([^)]*\))?\s*$"
)

# Lines that look like spell meta (Casting Time / Range / Components / Duration)
META_LINE_RE = re.compile(
    r"(?im)^\s*(casting\s*time|range|components?|duration)\s*:",
)

SCHOOL_LEVEL_RE = re.compile(
    r"(?i)\b(?:cantrip|\d+(?:st|nd|rd|th)[\-\s]?level)\b"
)

# Decorative / non-mechanical unknown_fields keys to drop after extraction.
DECORATIVE_UNKNOWN_KEYS = frozenset(
    {
        "artist",
        "arttype",
        "artcredit",
        "artwork",
        "illustrationartist",
        "illustrationtitle",
        "producttitle",
        "set",
        "setname",
        "setnumber",
        "sourceversion",
        "version",
        "sourceset",
    }
)


def looks_like_spell_chunk(text: str) -> bool:
    """True when chunk has spell-shaped signals worth sending to Claude."""
    if not text or not text.strip():
        return False
    if META_LINE_RE.search(text):
        return True
    if SCHOOL_LEVEL_RE.search(text):
        return True
    return False


def filter_decorative_unknown_fields(
    unknown: dict[str, Any] | None,
) -> dict[str, Any] | None:
    if not unknown:
        return None
    cleaned = {
        k: v
        for k, v in unknown.items()
        if k.lower() not in DECORATIVE_UNKNOWN_KEYS
    }
    return cleaned or None


@dataclass
class SplitEntry:
    text: str
    name_hint: str | None = None
    page: int | None = None
    start_line: int = 0
    end_line: int = 0


@dataclass
class SplitSection:
    title: str | None
    entries: list[SplitEntry] = field(default_factory=list)
    leftover_text: str = ""
    body_text: str = ""
    health_ok: bool = True
    health_reasons: list[str] = field(default_factory=list)


@dataclass
class Tier1Result:
    sections: list[SplitSection]
    used_page_markers: bool = False


def _page_for_offset(text: str, offset: int) -> int | None:
    page = None
    for match in PAGE_MARKER_RE.finditer(text):
        if match.start() > offset:
            break
        try:
            page = int(match.group(1))
        except ValueError:
            continue
    return page


def _strip_page_markers(text: str) -> str:
    return PAGE_MARKER_RE.sub("", text)


def _looks_like_entry_start(line: str, next_lines: list[str]) -> bool:
    stripped = line.strip()
    if not stripped or len(stripped) > 80:
        return False
    if SECTION_HEADER_RE.match(stripped):
        return False
    if PAGE_MARKER_RE.match(stripped):
        return False
    if META_LINE_RE.match(stripped):
        return False
    # School / level lines are never entry titles
    if re.search(r"(?i)\bcantrip\b", stripped):
        return False
    if re.search(r"(?i)\d+(?:st|nd|rd|th)[\-\s]?level\b", stripped):
        return False
    entry_re_ok = bool(ENTRY_START_RE.match(stripped))
    # Prefer starts followed by meta lines or school/level lines
    follow_ok = False
    for peek in next_lines[:4]:
        if not peek.strip():
            continue
        if META_LINE_RE.match(peek):
            follow_ok = True
            break
        peek_s = peek.strip()
        if re.search(r"(?i)\bcantrip\b", peek_s):
            follow_ok = True
            break
        if re.search(r"(?i)\d+(?:st|nd|rd|th)[\-\s]?level\b", peek_s):
            follow_ok = True
            break
        break
    # #region agent log
    if follow_ok and (
        not entry_re_ok
        or re.match(r"^\d", stripped)
        or "." in stripped
        or "sting" in stripped.lower()
    ):
        try:
            import json
            import time

            with open(
                "/Users/lennart.lucas/Documents/Github/RPG-Manager/.cursor/debug-5823b4.log",
                "a",
                encoding="utf-8",
            ) as _f:
                _f.write(
                    json.dumps(
                        {
                            "sessionId": "5823b4",
                            "hypothesisId": "A",
                            "location": "tier1_split.py:_looks_like_entry_start",
                            "message": "candidate title with follow-up meta/school",
                            "data": {
                                "stripped": stripped[:80],
                                "entry_re_ok": entry_re_ok,
                                "starts_with_digit": bool(re.match(r"^\d", stripped)),
                                "has_dot": "." in stripped,
                                "follow_ok": follow_ok,
                                "will_accept": False if not entry_re_ok else None,
                            },
                            "timestamp": int(time.time() * 1000),
                        }
                    )
                    + "\n"
                )
        except Exception:
            pass
    # #endregion
    if not entry_re_ok:
        return False
    if follow_ok:
        return True
    # ALL CAPS short titles are common spell names
    letters = re.sub(r"[^A-Za-z]", "", stripped)
    if letters and letters.isupper() and 2 <= len(letters) <= 40:
        return True
    return False


def _split_into_sections(text: str) -> list[tuple[str | None, str]]:
    lines = text.splitlines(keepends=True)
    sections: list[tuple[str | None, list[str]]] = []
    current_title: str | None = None
    current_lines: list[str] = []

    for line in lines:
        if SECTION_HEADER_RE.match(line.strip()):
            if current_lines or current_title is not None:
                sections.append((current_title, current_lines))
            current_title = line.strip()
            current_lines = []
            continue
        current_lines.append(line)

    if current_lines or current_title is not None:
        sections.append((current_title, current_lines))

    if not sections:
        return [(None, text)]

    return [(title, "".join(body_lines)) for title, body_lines in sections]


def _split_section_entries(section_text: str, full_text: str, base_offset: int) -> tuple[list[SplitEntry], str]:
    lines = section_text.splitlines()
    starts: list[int] = []
    for i, line in enumerate(lines):
        peek = lines[i + 1 : i + 5]
        if _looks_like_entry_start(line, peek):
            starts.append(i)

    if not starts:
        return [], section_text.strip()

    entries: list[SplitEntry] = []
    for idx, start in enumerate(starts):
        end = starts[idx + 1] if idx + 1 < len(starts) else len(lines)
        chunk_lines = lines[start:end]
        chunk = "\n".join(chunk_lines).strip()
        if not chunk:
            continue
        name_hint = lines[start].strip()
        # #region agent log
        if "sting" in chunk.lower() or "10.000" in chunk:
            try:
                import json
                import time

                with open(
                    "/Users/lennart.lucas/Documents/Github/RPG-Manager/.cursor/debug-5823b4.log",
                    "a",
                    encoding="utf-8",
                ) as _f:
                    _f.write(
                        json.dumps(
                            {
                                "sessionId": "5823b4",
                                "hypothesisId": "C",
                                "location": "tier1_split.py:_split_section_entries",
                                "message": "chunk may contain digit-named spell",
                                "data": {
                                    "name_hint": name_hint[:80],
                                    "start_line_idx": start,
                                    "end_line_idx": end,
                                    "chunk_has_stings": "Stings" in chunk
                                    or "10.000" in chunk,
                                    "chunk_preview": chunk[:200],
                                },
                                "timestamp": int(time.time() * 1000),
                            }
                        )
                        + "\n"
                    )
            except Exception:
                pass
        # #endregion
        # Approximate offset for page lookup
        prefix = "\n".join(lines[:start])
        offset = base_offset + len(prefix)
        entries.append(
            SplitEntry(
                text=chunk,
                name_hint=name_hint,
                page=_page_for_offset(full_text, offset),
                start_line=start,
                end_line=end - 1,
            )
        )

    # Leftover: text before first entry
    leftover_parts: list[str] = []
    if starts and starts[0] > 0:
        leftover_parts.append("\n".join(lines[: starts[0]]).strip())
    leftover = "\n\n".join(p for p in leftover_parts if p)
    return entries, leftover


def health_check_section(entries: list[SplitEntry], leftover: str) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    count = len(entries)
    if count < 3:
        reasons.append(f"implausible_entry_count:{count}")
    if count > 150:
        reasons.append(f"implausible_entry_count:{count}")

    if entries:
        lengths = [len(e.text) for e in entries]
        median = sorted(lengths)[len(lengths) // 2]
        if median > 0:
            for length in lengths:
                if length > median * 10:
                    reasons.append("entry_length_outlier")
                    break

    leftover_stripped = leftover.strip()
    if leftover_stripped and len(leftover_stripped) > 400:
        reasons.append("large_leftover_text")

    # Fail health if too few entries for a "list" section, or outliers/leftover
    critical = [
        r
        for r in reasons
        if r.startswith("implausible_entry_count")
        or r == "entry_length_outlier"
        or r == "large_leftover_text"
    ]
    # Allow small sections (1–2) to fail into tier 2 rather than trust them
    ok = len(critical) == 0
    return ok, reasons


def split_document(text: str) -> Tier1Result:
    used_markers = bool(PAGE_MARKER_RE.search(text))
    working = text
    sections_raw = _split_into_sections(working)
    result_sections: list[SplitSection] = []

    # Track offsets into original text for page lookup
    search_from = 0
    for title, body in sections_raw:
        if title is not None:
            idx = working.find(title, search_from)
            if idx >= 0:
                base_offset = idx + len(title)
                search_from = base_offset
            else:
                base_offset = search_from
        else:
            base_offset = search_from

        entries, leftover = _split_section_entries(body, working, base_offset)
        ok, reasons = health_check_section(entries, leftover)
        result_sections.append(
            SplitSection(
                title=title,
                entries=entries,
                leftover_text=leftover,
                body_text=body,
                health_ok=ok and bool(entries),
                health_reasons=reasons
                if entries
                else (reasons + ["no_entries_found"]),
            )
        )
        if not entries and not reasons:
            result_sections[-1].health_ok = False
            result_sections[-1].health_reasons = ["no_entries_found"]

    # Drop empty preamble sections (blank lines before first header)
    result_sections = [
        s
        for s in result_sections
        if s.title is not None
        or s.entries
        or (s.body_text and s.body_text.strip())
    ]
    if not result_sections:
        result_sections = [
            SplitSection(
                title=None,
                entries=[],
                leftover_text="",
                body_text=working,
                health_ok=False,
                health_reasons=["no_entries_found"],
            )
        ]

    # If the whole doc produced no healthy sections and no section headers,
    # try splitting the entire cleaned body as one section.
    if (
        len(result_sections) == 1
        and not result_sections[0].health_ok
        and result_sections[0].title is None
    ):
        cleaned = _strip_page_markers(working)
        entries, leftover = _split_section_entries(cleaned, working, 0)
        ok, reasons = health_check_section(entries, leftover)
        result_sections = [
            SplitSection(
                title=None,
                entries=entries,
                leftover_text=leftover,
                body_text=cleaned,
                health_ok=ok and bool(entries),
                health_reasons=reasons
                if entries
                else (reasons + ["no_entries_found"]),
            )
        ]

    return Tier1Result(sections=result_sections, used_page_markers=used_markers)
