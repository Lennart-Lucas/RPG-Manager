from collections.abc import AsyncGenerator

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory
from app.models.user import User
from app.security.tokens import decode_access_token, parse_user_id_from_token
from app.services import auth_service

security_scheme = HTTPBearer(auto_error=False)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


def _parse_bearer_user_id(
    credentials: HTTPAuthorizationCredentials | None,
) -> int:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_access_token(credentials.credentials)
        return parse_user_id_from_token(payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


async def get_current_user(
    session: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security_scheme),
) -> User:
    user_id = _parse_bearer_user_id(credentials)
    user = await auth_service.get_user_by_id(session, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


async def get_current_active_user(
    user: User = Depends(get_current_user),
) -> User:
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )
    return user


async def get_current_dm_user(
    user: User = Depends(get_current_active_user),
) -> User:
    if not user.is_dm:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Dungeon Master access required",
        )
    return user


async def campaign_scope_user_id(session: AsyncSession, user: User) -> int:
    """Shared catalog owner for this server.

    Priority:
    1. Optional ``CAMPAIGN_OWNER_USER_ID`` override
    2. Earliest active DM account
    3. The authenticated caller (solo / no DM yet)
    """
    from app.config import settings

    owner = settings.campaign_owner_user_id
    if owner is not None and owner > 0:
        return owner

    result = await session.execute(
        select(User.id)
        .where(User.is_dm.is_(True), User.is_active.is_(True))
        .order_by(User.id.asc())
        .limit(1)
    )
    dm_id = result.scalar_one_or_none()
    if dm_id is not None:
        return int(dm_id)
    return user.id
