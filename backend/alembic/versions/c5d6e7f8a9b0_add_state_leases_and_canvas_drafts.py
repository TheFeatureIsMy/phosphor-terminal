"""add state_leases and canvas_drafts tables

Revision ID: c5d6e7f8a9b0
Revises: a7b8c9d0e1f2
Create Date: 2026-08-21

PRD §7.3 State Lease Monitor + §5.2 canvas save-draft persistence.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "c5d6e7f8a9b0"
down_revision = "a7b8c9d0e1f2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "state_leases",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("resource_key", sa.String(length=256), nullable=False, unique=True),
        sa.Column("owner", sa.String(length=128), nullable=False),
        sa.Column("purpose", sa.String(length=64), nullable=True),
        sa.Column("acquired_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("released", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.create_index("ix_state_leases_resource_key", "state_leases", ["resource_key"])

    op.create_table(
        "canvas_drafts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "strategy_id", postgresql.UUID(as_uuid=True),
            sa.ForeignKey("strategies_v2.id"), nullable=False, unique=True,
        ),
        sa.Column("graph", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default="{}"),
        sa.Column("dsl", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("dsl_hash", sa.String(length=128), nullable=True),
        sa.Column("updated_by", sa.String(length=128), nullable=False, server_default="canvas"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("canvas_drafts")
    op.drop_index("ix_state_leases_resource_key", table_name="state_leases")
    op.drop_table("state_leases")
