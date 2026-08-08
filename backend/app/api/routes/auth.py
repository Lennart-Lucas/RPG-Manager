from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import (
    campaign_scope_user_id,
    get_current_active_user,
    get_db,
)
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserPreferencesUpdate,
    UserResponse,
)
from app.services import auth_service

limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/auth", tags=["auth"])


async def _user_response(session: AsyncSession, user: User) -> UserResponse:
    owner_id = await campaign_scope_user_id(session, user)
    if owner_id == user.id:
        campaign_theme_id = user.theme_id
    else:
        owner = await session.get(User, owner_id)
        campaign_theme_id = owner.theme_id if owner is not None else user.theme_id
    return UserResponse(
        id=user.id,
        email=user.email,
        is_active=user.is_active,
        is_dm=user.is_dm,
        ai_integration=user.ai_integration,
        theme_id=user.theme_id,
        campaign_theme_id=campaign_theme_id,
        created_at=user.created_at,
    )


@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit("10/minute")
async def register(
    request: Request,
    body: RegisterRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    _, tokens = await auth_service.register_user(
        session,
        body.email,
        body.password,
        body.client_platform,
    )
    return tokens


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request,
    body: LoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    return await auth_service.login_user(session, body.email, body.password)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("30/minute")
async def refresh(
    request: Request,
    body: RefreshRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    return await auth_service.refresh_tokens(session, body.refresh_token)


@router.post("/logout", status_code=204)
async def logout(
    body: LogoutRequest,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await auth_service.logout_user(
        session,
        user.id,
        body.refresh_token if not body.logout_all else None,
        logout_all=body.logout_all,
    )


@router.get("/me", response_model=UserResponse)
async def me(
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> UserResponse:
    return await _user_response(session, user)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    body: UserPreferencesUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> UserResponse:
    user.ai_integration = body.ai_integration

    if body.theme_id is not None:
        if not user.is_dm:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Dungeon Master access required to set campaign theme",
            )
        owner_id = await campaign_scope_user_id(session, user)
        if owner_id == user.id:
            user.theme_id = body.theme_id
        else:
            owner = await session.get(User, owner_id)
            if owner is None:
                user.theme_id = body.theme_id
            else:
                owner.theme_id = body.theme_id

    await session.flush()
    await session.refresh(user)
    return await _user_response(session, user)
