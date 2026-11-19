"""provider config tenant

Revision ID: d0c6a2c13d8c
Revises: 4c13c0782708
Create Date: 2026-11-16 00:50:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd0c6a2c13d8c'
down_revision: Union[str, Sequence[str], None] = '4c13c0782708'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("provider_configs", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_provider_configs_tenant", "provider_configs", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index(
        "ix_provider_config_tenant", "provider_configs", ["tenant_id", "category"]
    )
    op.execute(
        "UPDATE provider_configs SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )


def downgrade() -> None:
    op.drop_index("ix_provider_config_tenant", table_name="provider_configs")
    op.drop_constraint("fk_provider_configs_tenant", "provider_configs", type_="foreignkey")
    op.drop_column("provider_configs", "tenant_id")
