"""strategy run tenant

Revision ID: 0679c9bd58aa
Revises: fdd9adf9d88a
Create Date: 2026-11-17 00:55:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '0679c9bd58aa'
down_revision: Union[str, Sequence[str], None] = 'fdd9adf9d88a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("strategy_runs", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_strategy_runs_tenant", "strategy_runs", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_strategy_runs_tenant_id", "strategy_runs", ["tenant_id"])
    op.execute(
        """
        UPDATE strategy_runs r
        SET tenant_id = v.tenant_id
        FROM strategy_versions v
        WHERE r.strategy_version_id = v.id AND r.tenant_id IS NULL
        """
    )
    op.execute(
        "UPDATE strategy_runs SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )

    op.execute(
        """
        CREATE POLICY tenant_isolation_strategy_runs ON strategy_runs
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE strategy_runs ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE strategy_runs DISABLE ROW LEVEL SECURITY")
    op.execute("DROP POLICY IF EXISTS tenant_isolation_strategy_runs ON strategy_runs")
    op.drop_index("ix_strategy_runs_tenant_id", table_name="strategy_runs")
    op.drop_constraint("fk_strategy_runs_tenant", "strategy_runs", type_="foreignkey")
    op.drop_column("strategy_runs", "tenant_id")
