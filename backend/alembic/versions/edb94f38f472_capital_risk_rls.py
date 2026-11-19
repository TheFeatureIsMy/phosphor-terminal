"""capital risk rls

Revision ID: edb94f38f472
Revises: fc32b319d45f
Create Date: 2026-11-17 00:35:00.000000
"""
from typing import Sequence, Union

from alembic import op


revision: str = 'edb94f38f472'
down_revision: Union[str, Sequence[str], None] = 'fc32b319d45f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = (
    ("capital_pools", "tenant_isolation_capital_pools"),
    ("risk_policies", "tenant_isolation_risk_policies"),
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
