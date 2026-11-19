"""backtest rls

Revision ID: 67e1aa0233ff
Revises: ac10e45b8067
Create Date: 2026-11-17 00:15:00.000000
"""
from typing import Sequence, Union

from alembic import op


revision: str = '67e1aa0233ff'
down_revision: Union[str, Sequence[str], None] = 'ac10e45b8067'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE POLICY tenant_isolation_backtest_runs ON backtest_runs
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE backtest_runs ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE backtest_runs DISABLE ROW LEVEL SECURITY")
    op.execute("DROP POLICY IF EXISTS tenant_isolation_backtest_runs ON backtest_runs")
