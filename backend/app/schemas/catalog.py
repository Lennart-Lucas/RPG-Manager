from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.models.catalog_item import CatalogKind


class CatalogItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    payload: dict[str, Any] | None = None


class CatalogItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    payload: dict[str, Any] | None = None


class CatalogItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    kind: CatalogKind
    name: str
    payload: dict[str, Any] | None = None
    created_at: datetime
    updated_at: datetime
