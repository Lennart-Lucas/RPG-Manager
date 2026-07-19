from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.catalog_item import CatalogKind


class CatalogItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class CatalogItemUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class CatalogItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    kind: CatalogKind
    name: str
    created_at: datetime
    updated_at: datetime
