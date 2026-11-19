"""strategy tenant scoping

Revision ID: 0469f666f59f
Revises: 7ce13db2b68e
Create Date: 2026-11-16 00:32:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '0469f666f59f'
down_revision: Union[str, Sequence[str], None] = '7ce13db2b68e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("strategies_v2", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_strategies_v2_tenant", "strategies_v2", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_strategies_v2_tenant_id", "strategies_v2", ["tenant_id"])

    op.add_column("strategy_versions", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_strategy_versions_tenant", "strategy_versions", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_strategy_versions_tenant_id", "strategy_versions", ["tenant_id"])

    # Existing installs need an owner for pre-tenant data. The first user's
    # tenant is used when present; otherwise a deterministic default tenant is
    # created so nothing is orphaned.
    op.execute(
        """
        INSERT INTO tenants (name, slug, status, created_at)
        SELECT 'Default', 'default', 'active', NOW()
        WHERE NOT EXISTS (SELECT 1 FROM tenants)
        """
    )
    op.execute(
        "UPDATE strategies_v2 SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )
    op.execute(
        "UPDATE strategy_versions SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )


def downgrade() -> None:
    op.drop_index("ix_strategy_versions_tenant_id", table_name="strategy_versions")
    op.drop_constraint("fk_strategy_versions_tenant", "strategy_versions", type_="foreignkey")
    op.drop_column("strategy_versions", "tenant_id")

    op.drop_index("ix_strategies_v2_tenant_id", table_name="strategies_v2")
    op.drop_constraint("fk_strategies_v2_tenant", "strategies_v2", type_="foreignkey")
    op.drop_column("strategies_v2", "tenant_id")
