"""provider foundation: drop ai_provider_configs, create provider_configs + provider_audit_logs, add AIUsageLog.provider_config_id

Revision ID: f6d3a74173ea
Revises: e5f6a7b8c9d0
Create Date: 2026-06-16 20:01:49.620315

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f6d3a74173ea'
down_revision: Union[str, Sequence[str], None] = 'e5f6a7b8c9d0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create provider_configs first (so FKs can reference it)
    op.create_table(
        "provider_configs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("provider_name", sa.String(), nullable=False),
        sa.Column("instance_name", sa.String(), nullable=True),
        sa.Column("config", sa.JSON(), nullable=False),
        sa.Column("credentials_ct", sa.Text(), nullable=True),
        sa.Column("credentials_fields", sa.JSON(), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("priority", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("status", sa.String(), nullable=False, server_default=sa.text("'unknown'")),
        sa.Column("credential_status", sa.String(), nullable=False, server_default=sa.text("'missing'")),
        sa.Column("last_sync_at", sa.DateTime(), nullable=True),
        sa.Column("last_error", sa.String(), nullable=True),
        sa.Column("latency_ms", sa.Integer(), nullable=True),
        sa.Column("rate_limit_remaining", sa.Integer(), nullable=True),
        sa.Column("rate_limit_reset_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "(category = 'llm' AND instance_name IS NOT NULL) OR "
            "(category != 'llm' AND instance_name IS NULL)",
            name="ck_instance_name_by_category",
        ),
    )
    op.create_index("ix_provider_config_category", "provider_configs", ["category"])
    op.create_index("ix_provider_config_provider_name", "provider_configs", ["provider_name"])
    op.create_index("ix_provider_config_cat_name", "provider_configs", ["category", "provider_name"])
    op.create_index("ix_provider_config_enabled", "provider_configs", ["enabled"])

    # 2. Add nullable FK to AIUsageLog (now provider_configs exists)
    with op.batch_alter_table("ai_usage_logs") as batch_op:
        batch_op.add_column(
            sa.Column("provider_config_id", sa.Integer(), nullable=True),
        )
        batch_op.create_foreign_key(
            "fk_ai_usage_logs_provider_config",
            "provider_configs",
            ["provider_config_id"], ["id"],
            ondelete="SET NULL",
        )

    # 3. Create provider_audit_logs (FK to provider_configs is now valid)
    op.create_table(
        "provider_audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("provider_id", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(), nullable=False),
        sa.Column("actor", sa.String(), nullable=True),
        sa.Column("before_hash", sa.String(), nullable=True),
        sa.Column("after_hash", sa.String(), nullable=True),
        sa.Column("ip", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["provider_id"], ["provider_configs.id"],
            ondelete="CASCADE",
        ),
    )
    op.create_index("ix_provider_audit_logs_provider_id", "provider_audit_logs", ["provider_id"])
    op.create_index("ix_provider_audit_logs_created_at", "provider_audit_logs", ["created_at"])

    # 4. Drop ai_provider_configs
    op.drop_table("ai_provider_configs")


def downgrade() -> None:
    op.create_table(
        "ai_provider_configs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("provider", sa.String(), nullable=False),
        sa.Column("api_key_encrypted", sa.String(), nullable=True),
        sa.Column("base_url", sa.String(), nullable=True),
        sa.Column("model", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean()),
        sa.Column("priority", sa.Integer()),
        sa.Column("created_at", sa.DateTime()),
        sa.Column("updated_at", sa.DateTime()),
    )

    # 1. Drop FK from ai_usage_logs first (before dropping referenced table)
    with op.batch_alter_table("ai_usage_logs") as batch_op:
        batch_op.drop_constraint("fk_ai_usage_logs_provider_config", type_="foreignkey")
        batch_op.drop_column("provider_config_id")

    # 2. Drop provider_audit_logs (FK to provider_configs)
    op.drop_index("ix_provider_audit_logs_created_at", table_name="provider_audit_logs")
    op.drop_index("ix_provider_audit_logs_provider_id", table_name="provider_audit_logs")
    op.drop_table("provider_audit_logs")

    # 3. Drop provider_configs (no remaining FKs referencing it)
    op.drop_index("ix_provider_config_enabled", table_name="provider_configs")
    op.drop_index("ix_provider_config_cat_name", table_name="provider_configs")
    op.drop_index("ix_provider_config_provider_name", table_name="provider_configs")
    op.drop_index("ix_provider_config_category", table_name="provider_configs")
    op.drop_table("provider_configs")
