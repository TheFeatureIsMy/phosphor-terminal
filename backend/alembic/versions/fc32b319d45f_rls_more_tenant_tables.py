"""rls more tenant tables

Revision ID: fc32b319d45f
Revises: 67e1aa0233ff
Create Date: 2026-11-17 00:25:00.000000
"""
from typing import Sequence, Union

from alembic import op


revision: str = 'fc32b319d45f'
down_revision: Union[str, Sequence[str], None] = '67e1aa0233ff'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    ("strategy_versions", "tenant_isolation_strategy_versions"),
    ("provider_configs", "tenant_isolation_provider_configs"),
    ("knowledge_documents", "tenant_isolation_knowledge_documents"),
    ("knowledge_chunks", "tenant_isolation_knowledge_chunks"),
)


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
