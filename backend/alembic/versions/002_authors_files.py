"""authors and files tables

Revision ID: 002
Revises: 001
Create Date: 2026-07-16

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "authors",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("links", sa.JSON(), nullable=True),
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
    op.create_index(op.f("ix_authors_user_id"), "authors", ["user_id"], unique=False)
    op.create_index(
        op.f("ix_authors_deleted_at"), "authors", ["deleted_at"], unique=False
    )

    op.create_table(
        "files",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("author_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("source", sa.String(length=2048), nullable=True),
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
        sa.ForeignKeyConstraint(
            ["author_id"], ["authors.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_files_user_id"), "files", ["user_id"], unique=False)
    op.create_index(
        op.f("ix_files_author_id"), "files", ["author_id"], unique=False
    )
    op.create_index(
        op.f("ix_files_deleted_at"), "files", ["deleted_at"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_files_deleted_at"), table_name="files")
    op.drop_index(op.f("ix_files_author_id"), table_name="files")
    op.drop_index(op.f("ix_files_user_id"), table_name="files")
    op.drop_table("files")
    op.drop_index(op.f("ix_authors_deleted_at"), table_name="authors")
    op.drop_index(op.f("ix_authors_user_id"), table_name="authors")
    op.drop_table("authors")
