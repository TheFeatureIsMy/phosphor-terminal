"""p1 strategy tenant rls

Revision ID: 45c657f1dcb4
Revises: 6ef0661da299
Create Date: 2026-11-17 02:45:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '45c657f1dcb4'
down_revision: Union[str, Sequence[str], None] = '6ef0661da299'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    (
        "strategy_rule_dsl_versions", "tenant_isolation_rule_dsl_versions",
        "UPDATE strategy_rule_dsl_versions x SET tenant_id = v.tenant_id "
        "FROM strategy_versions v WHERE x.strategy_version_id = v.id AND x.tenant_id IS NULL",
    ),
    (
        "strategy_version_upgrade_requests", "tenant_isolation_upgrade_requests",
        "UPDATE strategy_version_upgrade_requests x SET tenant_id = s.tenant_id "
        "FROM strategies_v2 s WHERE x.strategy_id = s.id AND x.tenant_id IS NULL",
    ),
    (
        "growth_reports", "tenant_isolation_growth_reports",
        "UPDATE growth_reports x SET tenant_id = v.tenant_id FROM strategy_versions v "
        "WHERE x.strategy_version_id = v.id AND x.tenant_id IS NULL",
    ),
    (
        "dryrun_runs", "tenant_isolation_dryrun_runs",
        "UPDATE dryrun_runs x SET tenant_id = v.tenant_id FROM strategy_versions v "
        "WHERE v.id::text = x.strategy_version_id AND x.tenant_id IS NULL",
    ),
)


def upgrade() -> None:
    for table, policy, backfill in TABLES:
        op.add_column(table, sa.Column("tenant_id", sa.Integer(), nullable=True))
        op.create_foreign_key(
            f"fk_{table}_tenant", table, "tenants",
            ["tenant_id"], ["id"], ondelete="SET NULL",
        )
        op.create_index(f"ix_{table}_tenant_id", table, ["tenant_id"])
        op.execute(backfill)
        op.execute(
            f"""
            CREATE POLICY {policy} ON {table}
              USING (
                tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
              )
              WITH CHECK (
                tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
              )
            """
        )
        op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    for table, policy, _ in reversed(TABLES):
        op.execute(f"ALTER TABLE {table} DISABLE ROW LEVEL SECURITY")
        op.execute(f"DROP POLICY IF EXISTS {policy} ON {table}")
        op.drop_index(f"ix_{table}_tenant_id", table_name=table)
        op.drop_constraint(f"fk_{table}_tenant", table, type_="foreignkey")
        op.drop_column(table, "tenant_id")
