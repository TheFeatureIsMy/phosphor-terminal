"""binding activity rls

Revision ID: 63491bf52939
Revises: d1ecaee8ec51
Create Date: 2026-11-17 02:05:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '63491bf52939'
down_revision: Union[str, Sequence[str], None] = 'd1ecaee8ec51'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    (
        "strategy_risk_policy_bindings", "tenant_isolation_risk_bindings",
        "UPDATE strategy_risk_policy_bindings b SET tenant_id = v.tenant_id "
        "FROM strategy_versions v WHERE b.strategy_version_id = v.id AND b.tenant_id IS NULL",
    ),
    (
        "strategy_activity_log", "tenant_isolation_activity_log",
        "UPDATE strategy_activity_log a SET tenant_id = s.tenant_id "
        "FROM strategies_v2 s WHERE a.strategy_id = s.id AND a.tenant_id IS NULL",
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
