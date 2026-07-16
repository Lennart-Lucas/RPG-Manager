"""Shared validation helpers for DM resource endpoints."""

from __future__ import annotations

from urllib.parse import urlparse

from fastapi import HTTPException, status

LINK_SOURCES = frozenset(
    {
        "website",
        "patreon",
        "drive",
        "dropbox",
        "mega",
        "reddit",
        "homebrewery",
        "gmbinder",
    }
)


def validate_name(name: str, *, field: str = "name") -> str:
    cleaned = name.strip()
    if not cleaned:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field} is required",
        )
    if len(cleaned) > 255:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field} must be at most 255 characters",
        )
    return cleaned


def validate_url(url: str | None, *, required: bool = False) -> str | None:
    if url is None:
        if required:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="url is required",
            )
        return None
    cleaned = url.strip()
    if not cleaned:
        if required:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="url is required",
            )
        return None
    if len(cleaned) > 2048:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="url must be at most 2048 characters",
        )
    parsed = urlparse(cleaned)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="url must be a valid http or https URL",
        )
    return cleaned


def validate_link_source(source: str) -> str:
    cleaned = source.strip().lower()
    if cleaned not in LINK_SOURCES:
        allowed = ", ".join(sorted(LINK_SOURCES))
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"source must be one of: {allowed}",
        )
    return cleaned


def normalize_links(links: list[dict] | None) -> list[dict[str, str]]:
    if not links:
        return []
    normalized: list[dict[str, str]] = []
    for item in links:
        if not isinstance(item, dict):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="each link must be an object with source and url",
            )
        source = item.get("source")
        url = item.get("url")
        if not isinstance(source, str) or not isinstance(url, str):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="each link must include source and url strings",
            )
        normalized.append(
            {
                "source": validate_link_source(source),
                "url": validate_url(url, required=True) or "",
            }
        )
    return normalized
