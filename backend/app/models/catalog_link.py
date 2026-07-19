from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.catalog_item import CatalogItem
    from app.models.user import User


class CatalogLink(Base):
    """Directed wiki-link edge from a source catalog item's text field to a target."""

    __tablename__ = "catalog_links"
    __table_args__ = (
        UniqueConstraint(
            "source_item_id",
            "target_item_id",
            "field_key",
            name="uq_catalog_links_source_target_field",
        ),
        Index("ix_catalog_links_target_item_id", "target_item_id"),
        Index("ix_catalog_links_source_item_id", "source_item_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    source_item_id: Mapped[int] = mapped_column(
        ForeignKey("catalog_items.id", ondelete="CASCADE"), nullable=False
    )
    target_item_id: Mapped[int] = mapped_column(
        ForeignKey("catalog_items.id", ondelete="CASCADE"), nullable=False
    )
    field_key: Mapped[str] = mapped_column(String(128), nullable=False)

    user: Mapped[User] = relationship()
    source_item: Mapped[CatalogItem] = relationship(
        foreign_keys=[source_item_id],
    )
    target_item: Mapped[CatalogItem] = relationship(
        foreign_keys=[target_item_id],
    )
