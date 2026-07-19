"""catalog_links table + duplicate name safety

Revision ID: 005
Revises: 004
Create Date: 2026-07-19

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "005"
down_revision: Union[str, None] = "004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Disambiguate any accidental active duplicates (should be none with the
    # existing unique index; this is a safety net for SQLite/dev drift).
    conn = op.get_bind()
    duplicates = conn.execute(
        sa.text(
            """
            SELECT user_id, kind, name, COUNT(*) AS cnt
            FROM catalog_items
            WHERE deleted_at IS NULL
            GROUP BY user_id, kind, name
            HAVING COUNT(*) > 1
            """
        )
    ).fetchall()
    for user_id, kind, name, _cnt in duplicates:
        rows = conn.execute(
            sa.text(
                """
                SELECT id FROM catalog_items
                WHERE user_id = :user_id
                  AND kind = :kind
                  AND name = :name
                  AND deleted_at IS NULL
                ORDER BY id ASC
                """
            ),
            {"user_id": user_id, "kind": kind, "name": name},
        ).fetchall()
        for index, (item_id,) in enumerate(rows):
            if index == 0:
                continue
            new_name = f"{name} ({index + 1})"
            conn.execute(
                sa.text(
                    "UPDATE catalog_items SET name = :new_name WHERE id = :id"
                ),
                {"new_name": new_name, "id": item_id},
            )

    op.create_table(
        "catalog_links",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("source_item_id", sa.Integer(), nullable=False),
        sa.Column("target_item_id", sa.Integer(), nullable=False),
        sa.Column("field_key", sa.String(length=128), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["source_item_id"], ["catalog_items.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["target_item_id"], ["catalog_items.id"], ondelete="CASCADE"
        ),
        sa.UniqueConstraint(
            "source_item_id",
            "target_item_id",
            "field_key",
            name="uq_catalog_links_source_target_field",
        ),
    )
    op.create_index(
        "ix_catalog_links_user_id", "catalog_links", ["user_id"]
    )
    op.create_index(
        "ix_catalog_links_target_item_id",
        "catalog_links",
        ["target_item_id"],
    )
    op.create_index(
        "ix_catalog_links_source_item_id",
        "catalog_links",
        ["source_item_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_catalog_links_source_item_id", table_name="catalog_links")
    op.drop_index("ix_catalog_links_target_item_id", table_name="catalog_links")
    op.drop_index("ix_catalog_links_user_id", table_name="catalog_links")
    op.drop_table("catalog_links")
