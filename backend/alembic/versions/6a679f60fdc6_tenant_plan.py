"""tenant plan

Revision ID: 6a679f60fdc6
Revises: c6670360b3b2
Create Date: 2026-11-18 01:20:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '6a679f60fdc6'
down_revision: Union[str, Sequence[str], None] = 'c6670360b3b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tenants",
        sa.Column("plan", sa.String(length=20), nullable=False, server_default="free"),
    )


def downgrade() -> None:
    op.drop_column("tenants", "plan")
