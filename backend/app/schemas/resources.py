from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


LinkSource = Literal[
    "website",
    "patreon",
    "drive",
    "dropbox",
    "mega",
    "reddit",
    "homebrewery",
    "gmbinder",
]


class AuthorLink(BaseModel):
    source: LinkSource
    url: str


class AuthorCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    links: list[AuthorLink] = Field(default_factory=list)


class AuthorUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    links: list[AuthorLink] | None = None


class AuthorResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    name: str
    links: list[Any] | None = None
    created_at: datetime
    updated_at: datetime


class FileCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    author_id: int
    source: str | None = Field(default=None, max_length=2048)
    processed: bool = False


class FileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    author_id: int | None = None
    source: str | None = Field(default=None, max_length=2048)
    processed: bool | None = None


class FileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    author_id: int
    name: str
    source: str | None = None
    processed: bool = False
    created_at: datetime
    updated_at: datetime
