"""agent profile runtime config columns

Revision ID: f1a2b3c4d5e6
Revises: c5d6e7f8a9b0
Create Date: 2026-08-27

Agent 平台一期：AgentProfile 增加沙箱运行时配置(Qoder / Claude Code / native)。
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "f1a2b3c4d5e6"
down_revision = "c5d6e7f8a9b0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("agent_profiles", sa.Column("runtime_type", sa.String(length=32), nullable=False, server_default="native"))
    op.add_column("agent_profiles", sa.Column("model", sa.String(length=128), nullable=True))
    op.add_column("agent_profiles", sa.Column("cwd", sa.String(length=512), nullable=True))
    op.add_column("agent_profiles", sa.Column("permission_mode", sa.String(length=32), nullable=False, server_default="readonly"))
    op.add_column("agent_profiles", sa.Column("allowed_tools", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="[]"))
    op.add_column("agent_profiles", sa.Column("max_turns", sa.Integer(), nullable=False, server_default="20"))
    op.add_column("agent_profiles", sa.Column("trigger_type", sa.String(length=32), nullable=False, server_default="manual"))
    op.add_column("agent_profiles", sa.Column("output_target", sa.String(length=32), nullable=False, server_default="inbox"))
    op.add_column("agent_profiles", sa.Column("system_prompt", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("agent_profiles", "system_prompt")
    op.drop_column("agent_profiles", "output_target")
    op.drop_column("agent_profiles", "trigger_type")
    op.drop_column("agent_profiles", "max_turns")
    op.drop_column("agent_profiles", "allowed_tools")
    op.drop_column("agent_profiles", "permission_mode")
    op.drop_column("agent_profiles", "cwd")
    op.drop_column("agent_profiles", "model")
    op.drop_column("agent_profiles", "runtime_type")
