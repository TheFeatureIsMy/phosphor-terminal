"""tenant execution profiles

Revision ID: b874197997a8
Revises: fdb0d616e729
Create Date: 2026-11-17 03:20:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b874197997a8'
down_revision: Union[str, Sequence[str], None] = 'fdb0d616e729'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "tenant_execution_profiles",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenants.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("mode", sa.String(length=24), nullable=False, server_default="disabled"),
        sa.Column("freqtrade_url", sa.String(length=256), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("max_open_trades", sa.Integer(), nullable=False, server_default="2"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.execute(
        """
        CREATE POLICY tenant_isolation_execution_profiles
          ON tenant_execution_profiles
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE tenant_execution_profiles ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE tenant_execution_profiles DISABLE ROW LEVEL SECURITY")
    op.execute(
        "DROP POLICY IF EXISTS tenant_isolation_execution_profiles "
        "ON tenant_execution_profiles"
    )
    op.drop_table("tenant_execution_profiles")
