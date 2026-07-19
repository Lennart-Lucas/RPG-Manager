from datetime import datetime
from enum import Enum

from pydantic import BaseModel, EmailStr, Field, model_validator

from app.config import settings


class ClientPlatform(str, Enum):
    desktop = "desktop"
    web = "web"
    android = "android"
    ios = "ios"


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)
    client_platform: ClientPlatform

    @model_validator(mode="after")
    def check_password_length(self) -> "RegisterRequest":
        if len(self.password) < settings.password_min_length:
            raise ValueError(
                f"Password must be at least {settings.password_min_length} characters"
            )
        return self


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str | None = None
    logout_all: bool = False

    @model_validator(mode="after")
    def require_refresh_unless_logout_all(self) -> "LogoutRequest":
        if not self.logout_all and not self.refresh_token:
            raise ValueError("refresh_token is required unless logout_all is true")
        return self


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    is_active: bool
    is_dm: bool
    ai_integration: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UserPreferencesUpdate(BaseModel):
    ai_integration: bool
