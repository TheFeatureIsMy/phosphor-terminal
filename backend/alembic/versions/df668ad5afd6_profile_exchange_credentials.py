"""profile exchange credentials

Revision ID: df668ad5afd6
Revises: c9640217b27c
Create Date: 2026-11-17 03:45:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'df668ad5afd6'
down_revision: Union[str, Sequence[str], None] = 'c9640217b27c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("tenant_execution_profiles", sa.Column("exchange_key_ct", sa.String(length=2048), nullable=True))
    op.add_column("tenant_execution_profiles", sa.Column("exchange_secret_ct", sa.String(length=2048), nullable=True))


def downgrade() -> None:
    op.drop_column("tenant_execution_profiles", "exchange_secret_ct")
    op.drop_column("tenant_execution_profiles", "exchange_key_ct")
