"""users.theme_id campaign appearance

Revision ID: 008
Revises: 007
Create Date: 2026-08-08

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "008"
down_revision: Union[str, None] = "007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "theme_id",
            sa.String(length=32),
            nullable=False,
            server_default="default",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "theme_id")
