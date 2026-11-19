"""strategies rls policy

Revision ID: a936cc9d0aeb
Revises: 0a31cacccf27
Create Date: 2026-11-16 23:55:00.000000

Creates the tenant policy for strategies_v2 but deliberately does NOT enable
row-level security yet. RLS is enabled table by table only after the API uses a
NOBYPASSRLS role and workers use the BYPASSRLS role.
"""
from typing import Sequence, Union

from alembic import op


revision: str = 'a936cc9d0aeb'
down_revision: Union[str, Sequence[str], None] = '0a31cacccf27'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE POLICY tenant_isolation_strategies_v2 ON strategies_v2
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )


def downgrade() -> None:
    op.execute(
        "DROP POLICY IF EXISTS tenant_isolation_strategies_v2 ON strategies_v2"
    )
