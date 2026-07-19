"""catalog_items table

Revision ID: 003
Revises: 002
Create Date: 2026-07-19

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "catalog_items",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("kind", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_catalog_items_user_id"),
        "catalog_items",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_catalog_items_kind"),
        "catalog_items",
        ["kind"],
        unique=False,
    )
    op.create_index(
        op.f("ix_catalog_items_deleted_at"),
        "catalog_items",
        ["deleted_at"],
        unique=False,
    )
    op.create_index(
        "uq_catalog_items_user_kind_name_active",
        "catalog_items",
        ["user_id", "kind", "name"],
        unique=True,
        postgresql_where=sa.text("deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_catalog_items_user_kind_name_active",
        table_name="catalog_items",
    )
    op.drop_index(op.f("ix_catalog_items_deleted_at"), table_name="catalog_items")
    op.drop_index(op.f("ix_catalog_items_kind"), table_name="catalog_items")
    op.drop_index(op.f("ix_catalog_items_user_id"), table_name="catalog_items")
    op.drop_table("catalog_items")
