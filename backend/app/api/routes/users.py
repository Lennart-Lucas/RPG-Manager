from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_dm_user, get_db
from app.models.user import User
from app.schemas.users import PageActivityRequest, UserActivityResponse
from app.services import user_activity_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserActivityResponse])
async def list_users(
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> list[UserActivityResponse]:
    # For now, only the current user. Easy to widen later.
    return [user_activity_service.user_activity_response(user)]


@router.post("/me/activity", response_model=UserActivityResponse)
async def report_page_activity(
    body: PageActivityRequest,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> UserActivityResponse:
    return await user_activity_service.record_page_activity(session, user, body)
