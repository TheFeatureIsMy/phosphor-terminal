"""session expiry

Revision ID: 452dd48c6232
Revises: 2cb80eebfcb7
Create Date: 2026-11-17 04:35:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '452dd48c6232'
down_revision: Union[str, Sequence[str], None] = '2cb80eebfcb7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("device_sessions", sa.Column("expires_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("device_sessions", "expires_at")
