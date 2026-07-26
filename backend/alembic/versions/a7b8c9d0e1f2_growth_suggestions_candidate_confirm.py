"""growth: add suggestions column + candidate confirmation tracking

Revision ID: a7b8c9d0e1f2
Revises: f6d3a74173ea
Create Date: 2026-07-09 22:50:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID as PG_UUID


revision: str = "a7b8c9d0e1f2"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("growth_reports", sa.Column("suggestions", sa.JSON(), nullable=True))
    op.add_column("strategy_candidates", sa.Column("confirmed_strategy_id", PG_UUID(as_uuid=True), nullable=True))
    op.add_column("strategy_candidates", sa.Column("confirmed_version_no", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_strategy_candidates_confirmed_strategy",
        "strategy_candidates",
        "strategies_v2",
        ["confirmed_strategy_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint("fk_strategy_candidates_confirmed_strategy", "strategy_candidates", type_="foreignkey")
    op.drop_column("strategy_candidates", "confirmed_version_no")
    op.drop_column("strategy_candidates", "confirmed_strategy_id")
    op.drop_column("growth_reports", "suggestions")
