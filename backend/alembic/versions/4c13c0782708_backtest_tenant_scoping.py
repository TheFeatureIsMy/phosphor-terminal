"""backtest tenant scoping

Revision ID: 4c13c0782708
Revises: 0469f666f59f
Create Date: 2026-11-16 00:40:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '4c13c0782708'
down_revision: Union[str, Sequence[str], None] = '0469f666f59f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("backtest_runs", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_backtest_runs_tenant", "backtest_runs", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_backtest_runs_tenant_id", "backtest_runs", ["tenant_id"])
    op.execute(
        "UPDATE backtest_runs SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )


def downgrade() -> None:
    op.drop_index("ix_backtest_runs_tenant_id", table_name="backtest_runs")
    op.drop_constraint("fk_backtest_runs_tenant", "backtest_runs", type_="foreignkey")
    op.drop_column("backtest_runs", "tenant_id")
