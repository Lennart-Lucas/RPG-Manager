from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.attributes import flag_modified

from app.models.user import User
from app.schemas.users import PageActivityRequest, RecentPageVisit, UserActivityResponse

RECENT_PAGES_LIMIT = 8
LAST_ACTIVE_THROTTLE = timedelta(seconds=60)


def _parse_recent_pages(raw: Any) -> list[RecentPageVisit]:
    if not isinstance(raw, list):
        return []
    out: list[RecentPageVisit] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        path = str(entry.get("path") or "").strip()
        if not path:
            continue
        title = str(entry.get("title") or "").strip()
        visited_raw = entry.get("visited_at") or entry.get("visitedAt")
        try:
            if isinstance(visited_raw, datetime):
                visited_at = visited_raw
            elif isinstance(visited_raw, str) and visited_raw:
                visited_at = datetime.fromisoformat(
                    visited_raw.replace("Z", "+00:00")
                )
            else:
                continue
        except ValueError:
            continue
        if visited_at.tzinfo is None:
            visited_at = visited_at.replace(tzinfo=UTC)
        out.append(
            RecentPageVisit(path=path, title=title or path, visited_at=visited_at)
        )
    return out


def user_activity_response(user: User) -> UserActivityResponse:
    return UserActivityResponse(
        id=user.id,
        email=user.email,
        is_dm=user.is_dm,
        last_login_at=user.last_login_at,
        last_active_at=user.last_active_at,
        recent_pages=_parse_recent_pages(user.recent_pages),
    )


def mark_login_activity(user: User, *, now: datetime | None = None) -> None:
    stamp = now or datetime.now(UTC)
    user.last_login_at = stamp
    user.last_active_at = stamp


async def record_page_activity(
    session: AsyncSession,
    user: User,
    body: PageActivityRequest,
) -> UserActivityResponse:
    now = datetime.now(UTC)
    path = body.path.strip()
    title = body.title.strip() or path

    last_active = user.last_active_at
    if last_active is not None and last_active.tzinfo is None:
        last_active = last_active.replace(tzinfo=UTC)
    if last_active is None or now - last_active >= LAST_ACTIVE_THROTTLE:
        user.last_active_at = now

    pages = [
        page.model_dump(mode="json")
        for page in _parse_recent_pages(user.recent_pages)
        if page.path != path
    ]
    pages.insert(
        0,
        RecentPageVisit(path=path, title=title, visited_at=now).model_dump(
            mode="json"
        ),
    )
    user.recent_pages = pages[:RECENT_PAGES_LIMIT]
    flag_modified(user, "recent_pages")
    await session.flush()
    return user_activity_response(user)
