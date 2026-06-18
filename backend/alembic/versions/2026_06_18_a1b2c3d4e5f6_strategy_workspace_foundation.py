"""strategy workspace foundation: activity log + backtest UUID columns

Revision ID: a1b2c3d4e5f6
Revises: 3d1170805af5
Create Date: 2026-06-18 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID as PG_UUID


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '3d1170805af5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create strategy_activity_log table
    op.create_table(
        "strategy_activity_log",
        sa.Column("id", PG_UUID(as_uuid=True), primary_key=True),
        sa.Column("strategy_id", PG_UUID(as_uuid=True), nullable=False),
        sa.Column("kind", sa.String(64), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("actor", sa.String(128), nullable=True),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("delta", sa.JSON(), nullable=True),
        sa.Column("ref_kind", sa.String(32), nullable=True),
        sa.Column("ref_id", PG_UUID(as_uuid=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["strategy_id"], ["strategies_v2.id"],
            ondelete="CASCADE",
            name="fk_activity_log_strategy",
        ),
    )
    op.create_index(
        "idx_activity_strategy_time",
        "strategy_activity_log",
        ["strategy_id", sa.text("occurred_at DESC")],
    )

    # 2. Add UUID columns to backtest_runs
    with op.batch_alter_table("backtest_runs") as batch_op:
        batch_op.add_column(
            sa.Column("strategy_uuid", PG_UUID(as_uuid=True), nullable=True),
        )
        batch_op.add_column(
            sa.Column("strategy_version_uuid", PG_UUID(as_uuid=True), nullable=True),
        )
        batch_op.create_foreign_key(
            "fk_backtest_runs_strategy_uuid",
            "strategies_v2",
            ["strategy_uuid"], ["id"],
        )
        batch_op.create_foreign_key(
            "fk_backtest_runs_strategy_version",
            "strategy_versions",
            ["strategy_version_uuid"], ["id"],
        )
    op.create_index(
        "idx_backtest_runs_strategy_uuid",
        "backtest_runs",
        ["strategy_uuid", sa.text("completed_at DESC")],
    )


def downgrade() -> None:
    # 1. Drop index and UUID columns from backtest_runs
    op.drop_index("idx_backtest_runs_strategy_uuid", table_name="backtest_runs")
    with op.batch_alter_table("backtest_runs") as batch_op:
        batch_op.drop_constraint("fk_backtest_runs_strategy_version", type_="foreignkey")
        batch_op.drop_constraint("fk_backtest_runs_strategy_uuid", type_="foreignkey")
        batch_op.drop_column("strategy_version_uuid")
        batch_op.drop_column("strategy_uuid")

    # 2. Drop strategy_activity_log table and index
    op.drop_index("idx_activity_strategy_time", table_name="strategy_activity_log")
    op.drop_table("strategy_activity_log")
