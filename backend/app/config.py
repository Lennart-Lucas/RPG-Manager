import os
from functools import lru_cache

from pydantic import computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", ".env.dev"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    debug: bool = False
    api_prefix: str = "/api/v1"

    database_url: str = (
        "postgresql+asyncpg://rpg_manager:rpg_manager@localhost:5435/rpg_manager"
    )
    database_url_sync: str = (
        "postgresql+psycopg2://rpg_manager:rpg_manager@localhost:5435/rpg_manager"
    )

    cors_origins: str = "http://localhost:3000,http://localhost:8011"
    cors_allow_origin_regex: str | None = None

    @computed_field
    @property
    def cors_origin_list(self) -> list[str]:
        if not self.cors_origins.strip():
            return []
        return [
            origin.strip()
            for origin in self.cors_origins.split(",")
            if origin.strip()
        ]

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def effective_cors_origin_regex(self) -> str | None:
        if self.cors_allow_origin_regex:
            return self.cors_allow_origin_regex
        if not self.is_production:
            return r"http://(localhost|127\.0\.0\.1)(:\d+)?"
        return None


def _running_in_docker() -> bool:
    if os.environ.get("IN_DOCKER") == "1":
        return True
    return os.path.exists("/.dockerenv")


def _database_url_for_host(url: str) -> str:
    if _running_in_docker():
        return (
            url.replace("@localhost:5435", "@db:5432")
            .replace("@127.0.0.1:5435", "@db:5432")
            .replace("@localhost:5432", "@db:5432")
            .replace("@127.0.0.1:5432", "@db:5432")
        )
    if "@db:" in url:
        return url.replace("@db:", "@localhost:").replace(":5432/", ":5435/")
    return url


def get_database_url_sync() -> str:
    return _database_url_for_host(settings.database_url_sync)


def get_database_url_async() -> str:
    return _database_url_for_host(settings.database_url)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
