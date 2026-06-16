"""add system_settings table with 4 seed rows

Revision ID: 3d1170805af5
Revises: f6d3a74173ea
Create Date: 2026-06-17 02:08:06.167087

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3d1170805af5'
down_revision: Union[str, Sequence[str], None] = 'f6d3a74173ea'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "system_settings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("key", sa.String(length=128), nullable=False, unique=True),
        sa.Column("value", sa.JSON(), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("updated_by", sa.String(length=64), nullable=True),
    )
    op.create_index("ix_system_settings_category", "system_settings", ["category"])

    op.bulk_insert(
        sa.table(
            "system_settings",
            sa.column("key", sa.String),
            sa.column("value", sa.JSON),
            sa.column("category", sa.String),
            sa.column("updated_at", sa.DateTime),
            sa.column("updated_by", sa.String),
        ),
        [
            {"key": "general.default_language", "value": {"value": "zh-CN"}, "category": "general", "updated_at": sa.func.now(), "updated_by": "system"},
            {"key": "risk.max_single_loss", "value": {"value": 5.0}, "category": "risk", "updated_at": sa.func.now(), "updated_by": "system"},
            {"key": "privacy.share_ai_prompts", "value": {"value": False}, "category": "privacy", "updated_at": sa.func.now(), "updated_by": "system"},
            {"key": "retention.logs_days", "value": {"value": 30}, "category": "retention", "updated_at": sa.func.now(), "updated_by": "system"},
        ],
    )


def downgrade() -> None:
    op.drop_index("ix_system_settings_category", table_name="system_settings")
    op.drop_table("system_settings")
