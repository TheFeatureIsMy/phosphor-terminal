"""canvas draft rls

Revision ID: d1ecaee8ec51
Revises: 66b99c27f75e
Create Date: 2026-11-17 01:55:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd1ecaee8ec51'
down_revision: Union[str, Sequence[str], None] = '66b99c27f75e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("canvas_drafts", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_canvas_drafts_tenant", "canvas_drafts", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_canvas_drafts_tenant_id", "canvas_drafts", ["tenant_id"])
    op.execute(
        """
        UPDATE canvas_drafts d
        SET tenant_id = s.tenant_id
        FROM strategies_v2 s
        WHERE d.strategy_id = s.id AND d.tenant_id IS NULL
        """
    )
    op.execute(
        """
        CREATE POLICY tenant_isolation_canvas_drafts ON canvas_drafts
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE canvas_drafts ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE canvas_drafts DISABLE ROW LEVEL SECURITY")
    op.execute("DROP POLICY IF EXISTS tenant_isolation_canvas_drafts ON canvas_drafts")
    op.drop_index("ix_canvas_drafts_tenant_id", table_name="canvas_drafts")
    op.drop_constraint("fk_canvas_drafts_tenant", "canvas_drafts", type_="foreignkey")
    op.drop_column("canvas_drafts", "tenant_id")
