"""p0 execution risk tenant rls

Revision ID: 6ef0661da299
Revises: ccb10ee514e9
Create Date: 2026-11-17 02:30:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '6ef0661da299'
down_revision: Union[str, Sequence[str], None] = 'ccb10ee514e9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    (
        "trade_intents", "tenant_isolation_trade_intents",
        "UPDATE trade_intents x SET tenant_id = r.tenant_id FROM strategy_runs r "
        "WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
    ),
    (
        "risk_decisions", "tenant_isolation_risk_decisions",
        "UPDATE risk_decisions x SET tenant_id = r.tenant_id FROM strategy_runs r "
        "WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
    ),
    (
        "reconciliation_events", "tenant_isolation_reconciliation_events",
        "UPDATE reconciliation_events x SET tenant_id = r.tenant_id FROM strategy_runs r "
        "WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
    ),
    (
        "order_attributions", "tenant_isolation_order_attributions",
        "UPDATE order_attributions x SET tenant_id = v.tenant_id FROM strategy_versions v "
        "WHERE x.strategy_version_id = v.id AND x.tenant_id IS NULL",
    ),
    (
        "portfolio_snapshots", "tenant_isolation_portfolio_snapshots",
        "UPDATE portfolio_snapshots x SET tenant_id = r.tenant_id FROM strategy_runs r "
        "WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
    ),
    (
        "circuit_breaker_events", "tenant_isolation_circuit_breaker_events",
        "UPDATE circuit_breaker_events x SET tenant_id = r.tenant_id FROM strategy_runs r "
        "WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
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
    op.execute(
        """
        UPDATE risk_decisions x SET tenant_id = t.tenant_id
        FROM trade_intents t
        WHERE x.trade_intent_id = t.id AND x.tenant_id IS NULL
        """
    )


def downgrade() -> None:
    for table, policy, _ in reversed(TABLES):
        op.execute(f"ALTER TABLE {table} DISABLE ROW LEVEL SECURITY")
        op.execute(f"DROP POLICY IF EXISTS {policy} ON {table}")
        op.drop_index(f"ix_{table}_tenant_id", table_name=table)
        op.drop_constraint(f"fk_{table}_tenant", table, type_="foreignkey")
        op.drop_column(table, "tenant_id")
