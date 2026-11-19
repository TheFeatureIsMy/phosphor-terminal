"""generated artifacts rls

Revision ID: fdd9adf9d88a
Revises: edb94f38f472
Create Date: 2026-11-17 00:45:00.000000
"""
from typing import Sequence, Union

from alembic import op


revision: str = 'fdd9adf9d88a'
down_revision: Union[str, Sequence[str], None] = 'edb94f38f472'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE POLICY tenant_isolation_generated_artifacts
          ON generated_strategy_artifacts
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE generated_strategy_artifacts ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE generated_strategy_artifacts DISABLE ROW LEVEL SECURITY")
    op.execute(
        "DROP POLICY IF EXISTS tenant_isolation_generated_artifacts "
        "ON generated_strategy_artifacts"
    )
