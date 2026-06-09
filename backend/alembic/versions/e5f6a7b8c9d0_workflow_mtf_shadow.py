"""Workflow states, MTF guard events, shadow strategy drafts, failure clusters, trade review labels, strategy upgrade requests

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-06-08
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "e5f6a7b8c9d0"
down_revision = "d4e5f6a7b8c9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- Workflow Layer ---
    op.create_table(
        "workflow_states",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("workflow_date", sa.Date(), nullable=False, unique=True),
        sa.Column("global_state", sa.String(24), nullable=False, server_default="not_started"),
        sa.Column("current_step", sa.String(32), nullable=False, server_default="mission_control"),
        sa.Column("steps", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_workflow_states_date", "workflow_states", ["workflow_date"], unique=True)

    # --- MTF Guard Events ---
    op.create_table(
        "mtf_guard_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("strategy_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("strategy_version_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("symbol", sa.String(32), nullable=False),
        sa.Column("exchange", sa.String(32), nullable=True),
        sa.Column("fast_timeframe", sa.String(8), nullable=False),
        sa.Column("slow_timeframe", sa.String(8), nullable=False),
        sa.Column("structure_type", sa.String(32), nullable=False),
        sa.Column("structure_id", sa.String(64), nullable=True),
        sa.Column("guard_state", sa.String(32), nullable=False),
        sa.Column("action", sa.String(32), nullable=False),
        sa.Column("low_tf_price", sa.Numeric(), nullable=True),
        sa.Column("htf_zone_top", sa.Numeric(), nullable=True),
        sa.Column("htf_zone_bottom", sa.Numeric(), nullable=True),
        sa.Column("htf_candle_closed", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("reason_codes", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_mtf_guard_events_strategy", "mtf_guard_events", ["strategy_id", "symbol"])
    op.create_index("idx_mtf_guard_events_created", "mtf_guard_events", ["created_at"])

    # --- MTF Guard Backtest Stats ---
    op.create_table(
        "mtf_guard_backtest_stats",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("backtest_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("strategy_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("symbol", sa.String(32), nullable=False),
        sa.Column("blocked_entries_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reduced_size_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("temporary_violation_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reclaim_confirmed_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("invalidated_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("pnl_delta", sa.Numeric(), nullable=True),
        sa.Column("max_drawdown_delta", sa.Numeric(), nullable=True),
        sa.Column("false_breakout_avoided_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # --- Trade Review Labels ---
    op.create_table(
        "trade_review_labels",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("trade_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("runtime_snapshot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("feature_snapshot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("label", sa.String(128), nullable=False),
        sa.Column("label_source", sa.String(32), nullable=False),
        sa.Column("confidence", sa.Numeric(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_trade_review_labels_trade", "trade_review_labels", ["trade_id"])

    # --- Failure Clusters (persisted) ---
    op.create_table(
        "failure_clusters",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("strategy_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("label", sa.String(128), nullable=False),
        sa.Column("sample_size", sa.Integer(), nullable=False),
        sa.Column("total_loss", sa.Numeric(), nullable=True),
        sa.Column("avg_loss", sa.Numeric(), nullable=True),
        sa.Column("common_features", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("representative_trade_ids", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("status", sa.String(16), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_failure_clusters_strategy", "failure_clusters", ["strategy_id"])

    # --- Shadow Strategy Drafts ---
    op.create_table(
        "shadow_strategy_drafts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("source_type", sa.String(32), nullable=False),
        sa.Column("source_failure_cluster_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("target_strategy_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("target_strategy_version_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(256), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("status", sa.String(32), nullable=False, server_default="generated"),
        sa.Column("failure_pattern", postgresql.JSONB(), nullable=True),
        sa.Column("dsl_patch", postgresql.JSONB(), nullable=False),
        sa.Column("validation_state", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("backtest_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("dryrun_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_by", sa.String(64), nullable=False, server_default="growth_engine"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_shadow_drafts_strategy", "shadow_strategy_drafts", ["target_strategy_id"])
    op.create_index("idx_shadow_drafts_status", "shadow_strategy_drafts", ["status"])

    # --- Strategy Version Upgrade Requests ---
    op.create_table(
        "strategy_version_upgrade_requests",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("strategy_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("from_version_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("shadow_strategy_draft_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("proposed_version_name", sa.String(128), nullable=True),
        sa.Column("diff_summary", sa.Text(), nullable=True),
        sa.Column("validation_report", postgresql.JSONB(), nullable=True),
        sa.Column("approval_status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column("approved_by", sa.String(128), nullable=True),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_upgrade_requests_strategy", "strategy_version_upgrade_requests", ["strategy_id"])


def downgrade() -> None:
    op.drop_table("strategy_version_upgrade_requests")
    op.drop_table("shadow_strategy_drafts")
    op.drop_table("failure_clusters")
    op.drop_table("trade_review_labels")
    op.drop_table("mtf_guard_backtest_stats")
    op.drop_table("mtf_guard_events")
    op.drop_table("workflow_states")
