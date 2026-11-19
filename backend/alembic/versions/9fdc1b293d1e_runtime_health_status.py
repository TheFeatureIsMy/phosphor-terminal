"""runtime health status

Revision ID: 9fdc1b293d1e
Revises: df668ad5afd6
Create Date: 2026-11-17 04:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '9fdc1b293d1e'
down_revision: Union[str, Sequence[str], None] = 'df668ad5afd6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("tenant_execution_profiles", sa.Column("runtime_status", sa.String(length=24), nullable=False, server_default="unknown"))
    op.add_column("tenant_execution_profiles", sa.Column("last_health_at", sa.DateTime(), nullable=True))
    op.add_column("tenant_execution_profiles", sa.Column("last_error", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("tenant_execution_profiles", "last_error")
    op.drop_column("tenant_execution_profiles", "last_health_at")
    op.drop_column("tenant_execution_profiles", "runtime_status")
