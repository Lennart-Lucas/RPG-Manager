from __future__ import annotations

from enum import StrEnum
from typing import Any, Literal

from pydantic import BaseModel, Field


class BoundaryConfidence(StrEnum):
    verified_anchor = "verified_anchor"
    unverified = "unverified"
    classified_only = "classified_only"
    deterministic = "deterministic"


class ExtractSourceMeta(BaseModel):
    document_title: str | None = None
    section: str | None = None
    page: int | None = None


class ExtractJobRequest(BaseModel):
    kind: Literal["spells"] = "spells"
    document_title: str | None = Field(default=None, max_length=255)
    source_file_id: int | None = None
    text: str = Field(min_length=1, max_length=1_000_000)
    section_hint: str | None = Field(default=None, max_length=255)


class ExtractDraft(BaseModel):
    kind: Literal["spells"] = "spells"
    payload: dict[str, Any]
    source_text: str
    boundary_confidence: BoundaryConfidence
    duplicate_name_in_batch: bool = False
    duplicate_name_in_library: bool = False
    library_match_id: int | None = None
    library_match_name: str | None = None
    source: ExtractSourceMeta
    notes: str | None = None
    unknown_fields: dict[str, Any] | None = None
    needs_review: list[str] = Field(default_factory=list)
    tier: int = 1


class ExtractSectionSummary(BaseModel):
    title: str | None = None
    entry_count: int
    health_ok: bool
    health_reasons: list[str] = Field(default_factory=list)
    tier: int
    leftover_chars: int = 0


class ExtractJobResponse(BaseModel):
    drafts: list[ExtractDraft]
    section_summaries: list[ExtractSectionSummary]
