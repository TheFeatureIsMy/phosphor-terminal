"""enable strategies rls

Revision ID: ac10e45b8067
Revises: a936cc9d0aeb
Create Date: 2026-11-17 00:05:00.000000

Owners/superusers still bypass RLS, so this is a no-op for the current
single-role deployment. It takes effect once the API connects as
alphaloop_app (NOBYPASSRLS).
"""
from typing import Sequence, Union

from alembic import op


revision: str = 'ac10e45b8067'
down_revision: Union[str, Sequence[str], None] = 'a936cc9d0aeb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TABLE strategies_v2 ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE strategies_v2 DISABLE ROW LEVEL SECURITY")
