from __future__ import annotations

import re
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.catalog_item import CatalogItem, CatalogKind
from app.schemas.extract import (
    BoundaryConfidence,
    ExtractDraft,
    ExtractJobRequest,
    ExtractJobResponse,
    ExtractSectionSummary,
    ExtractSourceMeta,
)
from app.services.extract import claude_client
from app.services.extract.tier1_split import (
    SplitSection,
    filter_decorative_unknown_fields,
    looks_like_spell_chunk,
    split_document,
)
from app.services.extract.tier2_anchors import (
    parse_anchor_response,
    try_parse_spell_payload,
    verify_anchor_pair,
)


def _norm_name(name: str | None) -> str:
    if not name:
        return ""
    return re.sub(r"\s+", " ", name).strip().casefold()


async def _library_spell_names(
    session: AsyncSession, user_id: int
) -> dict[str, tuple[int, str]]:
    result = await session.execute(
        select(CatalogItem.id, CatalogItem.name).where(
            CatalogItem.user_id == user_id,
            CatalogItem.kind == CatalogKind.spells.value,
            CatalogItem.deleted_at.is_(None),
        )
    )
    out: dict[str, tuple[int, str]] = {}
    for item_id, name in result.all():
        key = _norm_name(name)
        if key:
            out[key] = (item_id, name)
    return out


def _apply_duplicate_flags(
    drafts: list[ExtractDraft], library: dict[str, tuple[int, str]]
) -> None:
    batch_counts: dict[str, int] = {}
    for draft in drafts:
        name = _norm_name(
            draft.payload.get("name")
            if isinstance(draft.payload.get("name"), str)
            else None
        )
        if name:
            batch_counts[name] = batch_counts.get(name, 0) + 1

    for draft in drafts:
        name = _norm_name(
            draft.payload.get("name")
            if isinstance(draft.payload.get("name"), str)
            else None
        )
        draft.duplicate_name_in_batch = bool(name and batch_counts.get(name, 0) > 1)
        if name and name in library:
            draft.duplicate_name_in_library = True
            draft.library_match_id, draft.library_match_name = library[name]
        else:
            draft.duplicate_name_in_library = False
            draft.library_match_id = None
            draft.library_match_name = None

        if draft.duplicate_name_in_batch and "duplicate_in_batch" not in draft.needs_review:
            draft.needs_review.append("duplicate_in_batch")
        if (
            draft.duplicate_name_in_library
            and "duplicate_in_library" not in draft.needs_review
        ):
            draft.needs_review.append("duplicate_in_library")
        if draft.unknown_fields and "unknown_fields" not in draft.needs_review:
            draft.needs_review.append("unknown_fields")
        if draft.notes and "notes_present" not in draft.needs_review:
            draft.needs_review.append("notes_present")


async def _extract_entry_with_retry(
    *,
    api_key: str,
    entry_text: str,
) -> tuple[dict[str, Any] | None, list[str], str | None, dict[str, Any] | None]:
    """Returns payload dict, needs_review, notes, unknown_fields."""
    needs: list[str] = []
    last_err: str | None = None
    data: dict[str, Any] | None = None

    for attempt in range(2):
        try:
            data = await claude_client.extract_spell(
                api_key=api_key, entry_text=entry_text
            )
        except claude_client.ClaudeError as exc:
            last_err = str(exc)
            if attempt == 0:
                continue
            needs.append("claude_error")
            return (
                None,
                needs,
                f"claude_error: {last_err}"[:500],
                {"_claude_error": last_err[:300], "_status": exc.status_code},
            )

        payload, err = try_parse_spell_payload(data)
        if payload is not None:
            dumped = payload.model_dump(mode="json")
            notes = dumped.pop("notes", None)
            unknown = dumped.pop("unknown_fields", None)
            return dumped, needs, notes, unknown

        last_err = err
        if attempt == 0:
            continue
        needs.append("schema_validation_failed")
        # Return raw-ish payload for review when possible
        if isinstance(data, dict):
            notes = data.get("notes") if isinstance(data.get("notes"), str) else None
            unknown = (
                data.get("unknown_fields")
                if isinstance(data.get("unknown_fields"), dict)
                else {"_validation_error": last_err}
            )
            return data, needs, notes, unknown
        return None, needs, None, {"_validation_error": last_err}

    needs.append("schema_validation_failed")
    return None, needs, None, {"_validation_error": last_err}


def _mark_not_a_spell_if_needed(
    payload: dict[str, Any],
    needs: list[str],
) -> None:
    name = payload.get("name")
    has_name = isinstance(name, str) and bool(name.strip())
    description = payload.get("description")
    has_description = isinstance(description, str) and bool(description.strip())
    if (
        not has_name
        and payload.get("level") is None
        and payload.get("school") is None
        and not has_description
    ):
        if "not_a_spell" not in needs:
            needs.append("not_a_spell")


def _not_a_spell_draft(
    *,
    name_hint: str | None,
    source_text: str,
    document_title: str | None,
    section: str | None,
    page: int | None,
    tier: int,
    boundary: BoundaryConfidence,
    extra_needs: list[str] | None = None,
) -> ExtractDraft:
    needs = ["not_a_spell", *(extra_needs or [])]
    return ExtractDraft(
        payload={"name": name_hint},
        source_text=source_text,
        boundary_confidence=boundary,
        source=ExtractSourceMeta(
            document_title=document_title,
            section=section,
            page=page,
        ),
        notes="Skipped Claude: chunk lacks spell-shaped signals "
        "(casting time / range / components / level-school line).",
        unknown_fields=None,
        needs_review=needs,
        tier=tier,
    )


def _finalize_extracted_draft(
    *,
    payload: dict[str, Any] | None,
    needs: list[str],
    notes: str | None,
    unknown: dict[str, Any] | None,
    name_hint: str | None,
    source_text: str,
    document_title: str | None,
    section: str | None,
    page: int | None,
    tier: int,
    boundary: BoundaryConfidence,
) -> ExtractDraft:
    if payload is None:
        payload = {"name": name_hint}
        if "schema_validation_failed" not in needs and "claude_error" not in needs:
            needs.append("extraction_failed")
        if notes is None and unknown and unknown.get("_claude_error"):
            notes = f"claude_error: {unknown.get('_claude_error')}"
    else:
        _mark_not_a_spell_if_needed(payload, needs)
    unknown = filter_decorative_unknown_fields(unknown)
    return ExtractDraft(
        payload=payload,
        source_text=source_text,
        boundary_confidence=boundary,
        source=ExtractSourceMeta(
            document_title=document_title,
            section=section,
            page=page,
        ),
        notes=notes,
        unknown_fields=unknown,
        needs_review=needs,
        tier=tier,
    )


async def _process_healthy_entries(
    *,
    api_key: str,
    section: SplitSection,
    document_title: str | None,
    drafts: list[ExtractDraft],
) -> None:
    for entry in section.entries:
        if not looks_like_spell_chunk(entry.text):
            drafts.append(
                _not_a_spell_draft(
                    name_hint=entry.name_hint,
                    source_text=entry.text,
                    document_title=document_title,
                    section=section.title,
                    page=entry.page,
                    tier=1,
                    boundary=BoundaryConfidence.deterministic,
                    extra_needs=["prefiltered"],
                )
            )
            continue

        payload, needs, notes, unknown = await _extract_entry_with_retry(
            api_key=api_key, entry_text=entry.text
        )
        drafts.append(
            _finalize_extracted_draft(
                payload=payload,
                needs=needs,
                notes=notes,
                unknown=unknown,
                name_hint=entry.name_hint,
                source_text=entry.text,
                document_title=document_title,
                section=section.title,
                page=entry.page,
                tier=1,
                boundary=BoundaryConfidence.deterministic,
            )
        )


async def _process_tier2_section(
    *,
    api_key: str,
    section: SplitSection,
    document_title: str | None,
    drafts: list[ExtractDraft],
) -> None:
    body = (section.body_text or section.leftover_text or "").strip()
    if not body and section.entries:
        body = "\n\n".join(e.text for e in section.entries)
    if not body:
        drafts.append(
            ExtractDraft(
                payload={"name": section.title or "Unknown section"},
                source_text="",
                boundary_confidence=BoundaryConfidence.unverified,
                source=ExtractSourceMeta(
                    document_title=document_title,
                    section=section.title,
                ),
                needs_review=["tier2_empty_section", *section.health_reasons],
                tier=2,
            )
        )
        return

    try:
        raw_anchors = await claude_client.detect_anchors(
            api_key=api_key, section_text=body
        )
    except claude_client.ClaudeError:
        drafts.append(
            ExtractDraft(
                payload={"name": section.title or "Section"},
                source_text=body[:4000],
                boundary_confidence=BoundaryConfidence.unverified,
                source=ExtractSourceMeta(
                    document_title=document_title,
                    section=section.title,
                ),
                needs_review=["tier2_anchor_detection_failed", *section.health_reasons],
                tier=2,
            )
        )
        return

    pairs = parse_anchor_response(raw_anchors)
    if not pairs:
        drafts.append(
            ExtractDraft(
                payload={"name": section.title or "Section"},
                source_text=body[:4000],
                boundary_confidence=BoundaryConfidence.unverified,
                source=ExtractSourceMeta(
                    document_title=document_title,
                    section=section.title,
                ),
                needs_review=["tier2_no_anchors", *section.health_reasons],
                tier=2,
            )
        )
        return

    for pair in pairs:
        span = verify_anchor_pair(body, pair["first_line"], pair["last_line"])
        if not span.verified or not span.entry_text:
            drafts.append(
                ExtractDraft(
                    payload={"name": span.name_hint},
                    source_text=(
                        f"FIRST: {pair['first_line']}\nLAST: {pair['last_line']}"
                    ),
                    boundary_confidence=BoundaryConfidence.unverified,
                    source=ExtractSourceMeta(
                        document_title=document_title,
                        section=section.title,
                    ),
                    needs_review=["boundary_unverified"],
                    tier=2,
                )
            )
            continue

        if not looks_like_spell_chunk(span.entry_text):
            drafts.append(
                _not_a_spell_draft(
                    name_hint=span.name_hint,
                    source_text=span.entry_text,
                    document_title=document_title,
                    section=section.title,
                    page=None,
                    tier=2,
                    boundary=BoundaryConfidence.verified_anchor,
                    extra_needs=["prefiltered"],
                )
            )
            continue

        payload, needs, notes, unknown = await _extract_entry_with_retry(
            api_key=api_key, entry_text=span.entry_text
        )
        drafts.append(
            _finalize_extracted_draft(
                payload=payload,
                needs=needs,
                notes=notes,
                unknown=unknown,
                name_hint=span.name_hint,
                source_text=span.entry_text,
                document_title=document_title,
                section=section.title,
                page=None,
                tier=2,
                boundary=BoundaryConfidence.verified_anchor,
            )
        )


async def run_extract_job(
    *,
    session: AsyncSession,
    user_id: int,
    api_key: str,
    request: ExtractJobRequest,
) -> ExtractJobResponse:
    split = split_document(request.text)
    drafts: list[ExtractDraft] = []
    summaries: list[ExtractSectionSummary] = []

    for section in split.sections:
        summaries.append(
            ExtractSectionSummary(
                title=section.title,
                entry_count=len(section.entries),
                health_ok=section.health_ok,
                health_reasons=list(section.health_reasons),
                tier=1 if section.health_ok else 2,
                leftover_chars=len(section.leftover_text or ""),
            )
        )
        if section.health_ok:
            await _process_healthy_entries(
                api_key=api_key,
                section=section,
                document_title=request.document_title,
                drafts=drafts,
            )
        else:
            await _process_tier2_section(
                api_key=api_key,
                section=section,
                document_title=request.document_title,
                drafts=drafts,
            )

    library = await _library_spell_names(session, user_id)
    _apply_duplicate_flags(drafts, library)
    return ExtractJobResponse(drafts=drafts, section_summaries=summaries)
