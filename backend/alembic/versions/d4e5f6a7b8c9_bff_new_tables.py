"""BFF new tables: circuit_breaker_events, volatility_locks, stop_protection_snapshots, live_readiness_checks

Revision ID: d4e5f6a7b8c9
Revises: b3f7a2c1d4e5
Create Date: 2026-06-06
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "d4e5f6a7b8c9"
down_revision = "b3f7a2c1d4e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "circuit_breaker_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("event_type", sa.String(32), nullable=False),
        sa.Column("account_id", sa.String(64), nullable=False, server_default="default"),
        sa.Column("strategy_id", sa.String(64), nullable=True),
        sa.Column("strategy_run_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("reason_codes", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("related_command_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("related_reconciliation_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("triggered_by", sa.String(32), nullable=False, server_default="system"),
        sa.Column("resolved", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_cb_events_type_created", "circuit_breaker_events", ["event_type", "created_at"])
    op.create_index("idx_cb_events_account", "circuit_breaker_events", ["account_id", "created_at"])

    op.create_table(
        "volatility_locks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("symbol", sa.String(32), nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False, server_default="5m"),
        sa.Column("lock_type", sa.String(32), nullable=False),
        sa.Column("trigger_value", sa.Numeric(20, 8), nullable=False),
        sa.Column("threshold_value", sa.Numeric(20, 8), nullable=False),
        sa.Column("reason_codes", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("action_taken", sa.String(32), nullable=False, server_default="lock_stop_update"),
        sa.Column("active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("locked_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("released_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_vol_lock_symbol_active", "volatility_locks", ["symbol", "active"])

    op.create_table(
        "stop_protection_snapshots",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("position_id", sa.String(64), nullable=False),
        sa.Column("symbol", sa.String(32), nullable=False),
        sa.Column("side", sa.String(8), nullable=False),
        sa.Column("entry_price", sa.Numeric(20, 8), nullable=False),
        sa.Column("raw_structure_stop", sa.Numeric(20, 8), nullable=True),
        sa.Column("last_known_good_stop", sa.Numeric(20, 8), nullable=True),
        sa.Column("secure_runtime_stop", sa.Numeric(20, 8), nullable=True),
        sa.Column("exchange_protective_stop", sa.Numeric(20, 8), nullable=True),
        sa.Column("volatility_locked", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("stop_update_allowed", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("reason_codes", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("structure_data", postgresql.JSONB(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_stop_prot_position", "stop_protection_snapshots", ["position_id", "created_at"])
    op.create_index("idx_stop_prot_symbol", "stop_protection_snapshots", ["symbol", "created_at"])

    op.create_table(
        "live_readiness_checks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("account_id", sa.String(64), nullable=False, server_default="default"),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("state", sa.String(32), nullable=False, server_default="NOT_READY"),
        sa.Column("can_start_paper", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("can_start_live_small", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("can_start_full_live", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("checks", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("blocking_reasons", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("warnings", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_readiness_account_created", "live_readiness_checks", ["account_id", "created_at"])


def downgrade() -> None:
    op.drop_table("live_readiness_checks")
    op.drop_table("stop_protection_snapshots")
    op.drop_table("volatility_locks")
    op.drop_table("circuit_breaker_events")
