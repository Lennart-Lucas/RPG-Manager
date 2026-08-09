from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class RecentPageVisit(BaseModel):
    path: str
    title: str
    visited_at: datetime


class UserActivityResponse(BaseModel):
    id: int
    email: EmailStr
    is_dm: bool
    last_login_at: datetime | None = None
    last_active_at: datetime | None = None
    recent_pages: list[RecentPageVisit] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class PageActivityRequest(BaseModel):
    path: str = Field(min_length=1, max_length=512)
    title: str = Field(default="", max_length=256)
