"""tenant execution credentials

Revision ID: c9640217b27c
Revises: b874197997a8
Create Date: 2026-11-17 03:35:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c9640217b27c'
down_revision: Union[str, Sequence[str], None] = 'b874197997a8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("tenant_execution_profiles", sa.Column("api_username", sa.String(length=128), nullable=True))
    op.add_column("tenant_execution_profiles", sa.Column("api_password_ct", sa.String(length=1024), nullable=True))


def downgrade() -> None:
    op.drop_column("tenant_execution_profiles", "api_password_ct")
    op.drop_column("tenant_execution_profiles", "api_username")
