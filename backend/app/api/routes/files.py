from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_dm_user, get_db
from app.models.user import User
from app.schemas.resources import FileCreate, FileResponse, FileUpdate
from app.services import file_service

router = APIRouter(prefix="/files", tags=["files"])


@router.get("", response_model=list[FileResponse])
async def list_files(
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> list[FileResponse]:
    files = await file_service.list_files(session, user.id)
    return [FileResponse.model_validate(f) for f in files]


@router.post("", response_model=FileResponse, status_code=201)
async def create_file(
    body: FileCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> FileResponse:
    resource = await file_service.create_file(session, user.id, body)
    return FileResponse.model_validate(resource)


@router.get("/{file_id}", response_model=FileResponse)
async def get_file(
    file_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> FileResponse:
    resource = await file_service.get_file(session, user.id, file_id)
    return FileResponse.model_validate(resource)


@router.patch("/{file_id}", response_model=FileResponse)
async def update_file(
    file_id: int,
    body: FileUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> FileResponse:
    resource = await file_service.update_file(session, user.id, file_id, body)
    return FileResponse.model_validate(resource)


@router.delete("/{file_id}", status_code=204)
async def delete_file(
    file_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> None:
    await file_service.delete_file(session, user.id, file_id)
