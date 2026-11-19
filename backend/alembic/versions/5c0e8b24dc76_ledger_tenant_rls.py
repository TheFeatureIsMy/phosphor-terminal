"""ledger tenant rls

Revision ID: 5c0e8b24dc76
Revises: 0679c9bd58aa
Create Date: 2026-11-17 01:05:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '5c0e8b24dc76'
down_revision: Union[str, Sequence[str], None] = '0679c9bd58aa'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "execution_ledger_events", sa.Column("tenant_id", sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        "fk_execution_ledger_events_tenant", "execution_ledger_events", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index(
        "ix_execution_ledger_events_tenant_id", "execution_ledger_events", ["tenant_id"]
    )
    op.execute(
        """
        UPDATE execution_ledger_events e
        SET tenant_id = r.tenant_id
        FROM strategy_runs r
        WHERE e.strategy_run_id = r.id AND e.tenant_id IS NULL
        """
    )
    op.execute(
        """
        CREATE POLICY tenant_isolation_ledger ON execution_ledger_events
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE execution_ledger_events ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE execution_ledger_events DISABLE ROW LEVEL SECURITY")
    op.execute("DROP POLICY IF EXISTS tenant_isolation_ledger ON execution_ledger_events")
    op.drop_index("ix_execution_ledger_events_tenant_id", table_name="execution_ledger_events")
    op.drop_constraint(
        "fk_execution_ledger_events_tenant", "execution_ledger_events", type_="foreignkey"
    )
    op.drop_column("execution_ledger_events", "tenant_id")
