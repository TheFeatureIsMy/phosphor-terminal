"""freqtrade runs and fills rls

Revision ID: 24b2af3b76ba
Revises: d287b7dc3bb5
Create Date: 2026-11-17 01:25:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '24b2af3b76ba'
down_revision: Union[str, Sequence[str], None] = 'd287b7dc3bb5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    (
        "freqtrade_runs", "tenant_isolation_freqtrade_runs",
        "UPDATE freqtrade_runs x SET tenant_id = r.tenant_id "
        "FROM strategy_runs r WHERE x.strategy_run_id = r.id AND x.tenant_id IS NULL",
    ),
    (
        "order_fills", "tenant_isolation_order_fills",
        "UPDATE order_fills x SET tenant_id = o.tenant_id "
        "FROM execution_orders o WHERE x.execution_order_id = o.id AND x.tenant_id IS NULL",
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
