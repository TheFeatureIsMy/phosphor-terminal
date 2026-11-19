"""remaining linked tenant rls

Revision ID: fdb0d616e729
Revises: 0de1a8ae545b
Create Date: 2026-11-17 03:05:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'fdb0d616e729'
down_revision: Union[str, Sequence[str], None] = '0de1a8ae545b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

RLS_TABLES = (
    (
        "feature_snapshots", "tenant_isolation_feature_snapshots",
        "UPDATE feature_snapshots x SET tenant_id = r.tenant_id FROM strategy_runs r "
        "WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
    ),
    (
        "failure_clusters", "tenant_isolation_failure_clusters",
        "UPDATE failure_clusters x SET tenant_id = s.tenant_id FROM strategies_v2 s "
        "WHERE x.strategy_id = s.id AND x.tenant_id IS NULL",
    ),
    (
        "mtf_guard_events", "tenant_isolation_mtf_guard_events",
        "UPDATE mtf_guard_events x SET tenant_id = v.tenant_id FROM strategy_versions v "
        "WHERE x.strategy_version_id = v.id AND x.tenant_id IS NULL",
    ),
    (
        "mtf_guard_backtest_stats", "tenant_isolation_mtf_backtest_stats",
        "UPDATE mtf_guard_backtest_stats x SET tenant_id = s.tenant_id FROM strategies_v2 s "
        "WHERE x.strategy_id = s.id AND x.tenant_id IS NULL",
    ),
)


def upgrade() -> None:
    for table, policy, backfill in RLS_TABLES:
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

    # Legacy integer strategy id: column only, RLS deferred.
    op.add_column("risk_events", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_risk_events_tenant", "risk_events", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_risk_events_tenant_id", "risk_events", ["tenant_id"])


def downgrade() -> None:
    op.drop_index("ix_risk_events_tenant_id", table_name="risk_events")
    op.drop_constraint("fk_risk_events_tenant", "risk_events", type_="foreignkey")
    op.drop_column("risk_events", "tenant_id")

    for table, policy, _ in reversed(RLS_TABLES):
        op.execute(f"ALTER TABLE {table} DISABLE ROW LEVEL SECURITY")
        op.execute(f"DROP POLICY IF EXISTS {policy} ON {table}")
        op.drop_index(f"ix_{table}_tenant_id", table_name=table)
        op.drop_constraint(f"fk_{table}_tenant", table, type_="foreignkey")
        op.drop_column(table, "tenant_id")
