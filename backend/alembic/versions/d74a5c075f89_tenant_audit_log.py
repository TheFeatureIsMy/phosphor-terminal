"""tenant audit log

Revision ID: d74a5c075f89
Revises: 8d3c2f1a9b7e
Create Date: 2026-11-18 02:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd74a5c075f89'
down_revision: Union[str, Sequence[str], None] = '8d3c2f1a9b7e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "tenant_audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("tenant_id", sa.Integer(), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("detail", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_tenant_audit_logs_tenant_id", "tenant_audit_logs", ["tenant_id"])
    op.create_index("ix_tenant_audit_logs_action", "tenant_audit_logs", ["action"])
    op.create_index("ix_tenant_audit_logs_created_at", "tenant_audit_logs", ["created_at"])
    op.execute(
        """
        CREATE POLICY tenant_isolation_tenant_audit_logs ON tenant_audit_logs
          USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int)
          WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int)
        """
    )
    op.execute("ALTER TABLE tenant_audit_logs ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE tenant_audit_logs DISABLE ROW LEVEL SECURITY")
    op.execute("DROP POLICY IF EXISTS tenant_isolation_tenant_audit_logs ON tenant_audit_logs")
    op.drop_index("ix_tenant_audit_logs_created_at", table_name="tenant_audit_logs")
    op.drop_index("ix_tenant_audit_logs_action", table_name="tenant_audit_logs")
    op.drop_index("ix_tenant_audit_logs_tenant_id", table_name="tenant_audit_logs")
    op.drop_table("tenant_audit_logs")
