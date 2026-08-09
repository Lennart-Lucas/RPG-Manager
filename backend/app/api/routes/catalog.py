from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import (
    campaign_scope_user_id,
    get_current_active_user,
    get_current_dm_user,
    get_db,
)
from app.models.catalog_item import CatalogKind
from app.models.user import User
from app.schemas.catalog import (
    CatalogItemCreate,
    CatalogItemResponse,
    CatalogItemUpdate,
    CatalogSearchHit,
)
from app.services import catalog_service

# Registered without {kind} so /catalog/search is not captured as a kind.
search_router = APIRouter(prefix="/catalog", tags=["catalog"])
router = APIRouter(prefix="/catalog/{kind}", tags=["catalog"])


@search_router.get("/search", response_model=list[CatalogSearchHit])
async def search_catalog_items(
    q: str = Query(default="", max_length=255),
    limit: int = Query(default=20, ge=1, le=50),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[CatalogSearchHit]:
    return await catalog_service.search_items(
        session, await campaign_scope_user_id(session, user), q, limit=limit
    )


@router.get("", response_model=list[CatalogItemResponse])
async def list_catalog_items(
    kind: CatalogKind,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[CatalogItemResponse]:
    items = await catalog_service.list_items(
        session, await campaign_scope_user_id(session, user), kind
    )
    return [CatalogItemResponse.model_validate(item) for item in items]


@router.post("", response_model=CatalogItemResponse, status_code=201)
async def create_catalog_item(
    kind: CatalogKind,
    body: CatalogItemCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> CatalogItemResponse:
    item = await catalog_service.create_item(
        session, await campaign_scope_user_id(session, user), kind, body
    )
    return CatalogItemResponse.model_validate(item)


@router.get("/{item_id}", response_model=CatalogItemResponse)
async def get_catalog_item(
    kind: CatalogKind,
    item_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> CatalogItemResponse:
    item = await catalog_service.get_item(
        session, await campaign_scope_user_id(session, user), kind, item_id
    )
    return CatalogItemResponse.model_validate(item)


@router.patch("/{item_id}", response_model=CatalogItemResponse)
async def update_catalog_item(
    kind: CatalogKind,
    item_id: int,
    body: CatalogItemUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> CatalogItemResponse:
    item = await catalog_service.update_item(
        session, await campaign_scope_user_id(session, user), kind, item_id, body
    )
    return CatalogItemResponse.model_validate(item)


@router.delete("/{item_id}", status_code=204)
async def delete_catalog_item(
    kind: CatalogKind,
    item_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_dm_user),
) -> None:
    await catalog_service.delete_item(
        session, await campaign_scope_user_id(session, user), kind, item_id
    )
