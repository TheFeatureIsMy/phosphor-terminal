"""RLS for legacy strategy-linked tables

Revision ID: 8d3c2f1a9b7e
Revises: 6a679f60fdc6
Create Date: 2026-11-18 01:40:00.000000
"""
from typing import Sequence, Union

from alembic import op


revision: str = '8d3c2f1a9b7e'
down_revision: Union[str, Sequence[str], None] = '6a679f60fdc6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = [
    ("ai_research_links", "tenant_isolation_ai_research_links"),
    ("attribution_reports", "tenant_isolation_attribution_reports"),
    ("canvas_workflows", "tenant_isolation_canvas_workflows"),
    ("freqai_runs", "tenant_isolation_freqai_runs"),
    ("risk_events", "tenant_isolation_risk_events"),
]


def upgrade() -> None:
    for table, policy in TABLES:
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
    for table, policy in reversed(TABLES):
        op.execute(f"ALTER TABLE {table} DISABLE ROW LEVEL SECURITY")
        op.execute(f"DROP POLICY IF EXISTS {policy} ON {table}")
