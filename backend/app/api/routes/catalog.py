from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.catalog_item import CatalogKind
from app.models.user import User
from app.schemas.catalog import (
    CatalogItemCreate,
    CatalogItemResponse,
    CatalogItemUpdate,
)
from app.services import catalog_service

router = APIRouter(prefix="/catalog/{kind}", tags=["catalog"])


@router.get("", response_model=list[CatalogItemResponse])
async def list_catalog_items(
    kind: CatalogKind,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[CatalogItemResponse]:
    items = await catalog_service.list_items(session, user.id, kind)
    return [CatalogItemResponse.model_validate(item) for item in items]


@router.post("", response_model=CatalogItemResponse, status_code=201)
async def create_catalog_item(
    kind: CatalogKind,
    body: CatalogItemCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> CatalogItemResponse:
    item = await catalog_service.create_item(session, user.id, kind, body)
    return CatalogItemResponse.model_validate(item)


@router.get("/{item_id}", response_model=CatalogItemResponse)
async def get_catalog_item(
    kind: CatalogKind,
    item_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> CatalogItemResponse:
    item = await catalog_service.get_item(session, user.id, kind, item_id)
    return CatalogItemResponse.model_validate(item)


@router.patch("/{item_id}", response_model=CatalogItemResponse)
async def update_catalog_item(
    kind: CatalogKind,
    item_id: int,
    body: CatalogItemUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> CatalogItemResponse:
    item = await catalog_service.update_item(
        session, user.id, kind, item_id, body
    )
    return CatalogItemResponse.model_validate(item)


@router.delete("/{item_id}", status_code=204)
async def delete_catalog_item(
    kind: CatalogKind,
    item_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await catalog_service.delete_item(session, user.id, kind, item_id)
