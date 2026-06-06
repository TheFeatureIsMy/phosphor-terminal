"""v2_5_completion

Revision ID: b3f7a2c1d4e5
Revises: cafb0a7659e2
Create Date: 2026-06-04 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID as PG_UUID


# revision identifiers, used by Alembic.
revision: str = 'b3f7a2c1d4e5'
down_revision: Union[str, Sequence[str], None] = 'cafb0a7659e2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""

    # ── feature_snapshots: add new columns ──────────────────────────────
    op.add_column('feature_snapshots', sa.Column('symbol', sa.String(32), nullable=False, server_default=''))
    op.add_column('feature_snapshots', sa.Column('market', sa.String(16), nullable=True))
    op.add_column('feature_snapshots', sa.Column('timeframe', sa.String(8), nullable=True))
    op.add_column('feature_snapshots', sa.Column('feature_version', sa.String(16), nullable=False, server_default='2.5'))
    op.add_column('feature_snapshots', sa.Column('technical_features', sa.JSON(), nullable=True))
    op.add_column('feature_snapshots', sa.Column('sentiment_features', sa.JSON(), nullable=True))
    op.add_column('feature_snapshots', sa.Column('onchain_features', sa.JSON(), nullable=True))
    op.add_column('feature_snapshots', sa.Column('manipulation_features', sa.JSON(), nullable=True))
    op.add_column('feature_snapshots', sa.Column('portfolio_features', sa.JSON(), nullable=True))
    op.add_column('feature_snapshots', sa.Column('data_quality', sa.String(16), nullable=True, server_default='complete'))
    op.add_column('feature_snapshots', sa.Column('strategy_run_id', PG_UUID(as_uuid=True), sa.ForeignKey('strategy_runs.id'), nullable=True))
    op.add_column('feature_snapshots', sa.Column('trade_intent_id', PG_UUID(as_uuid=True), sa.ForeignKey('trade_intents.id'), nullable=True))
    op.create_index('idx_feature_snapshots_symbol', 'feature_snapshots', ['symbol'])

    # ── portfolio_snapshots: add new columns ────────────────────────────
    op.add_column('portfolio_snapshots', sa.Column('strategy_run_id', PG_UUID(as_uuid=True), sa.ForeignKey('strategy_runs.id'), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('capital_pool_id', PG_UUID(as_uuid=True), sa.ForeignKey('capital_pools.id'), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('snapshot_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('total_equity', sa.Numeric(20, 8), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('available_cash', sa.Numeric(20, 8), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('total_exposure_pct', sa.Numeric(8, 6), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('daily_pnl_pct', sa.Numeric(8, 6), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('max_drawdown_pct', sa.Numeric(8, 6), nullable=True))
    op.add_column('portfolio_snapshots', sa.Column('open_positions_count', sa.Integer(), nullable=True, server_default='0'))
    op.add_column('portfolio_snapshots', sa.Column('raw_payload', sa.JSON(), nullable=True))
    op.create_index('idx_portfolio_snapshots_snapshot_at', 'portfolio_snapshots', [sa.text('snapshot_at DESC')])

    # ── inference_jobs ──────────────────────────────────────────────────
    op.create_table('inference_jobs',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('job_type', sa.String(64), nullable=False),
        sa.Column('model_name', sa.String(128), nullable=False),
        sa.Column('provider_id', PG_UUID(as_uuid=True), sa.ForeignKey('ai_provider_configs.id'), nullable=True),
        sa.Column('status', sa.String(16), nullable=False, server_default='queued'),
        sa.Column('input_payload', sa.JSON(), nullable=True),
        sa.Column('output_payload', sa.JSON(), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('submitted_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('timeout_sec', sa.Integer(), nullable=False, server_default='300'),
        sa.Column('estimated_cost_usd', sa.Numeric(12, 6), nullable=True),
        sa.Column('actual_cost_usd', sa.Numeric(12, 6), nullable=True),
    )
    op.create_index('idx_inference_jobs_status', 'inference_jobs', ['status'])
    op.create_index('idx_inference_jobs_model_status', 'inference_jobs', ['model_name', 'status'])
    op.create_index('idx_inference_jobs_submitted', 'inference_jobs', [sa.text('submitted_at DESC')])

    # ── remote_model_jobs ───────────────────────────────────────────────
    op.create_table('remote_model_jobs',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('model_name', sa.String(128), nullable=False),
        sa.Column('provider', sa.String(64), nullable=False),
        sa.Column('status', sa.String(16), nullable=False, server_default='queued'),
        sa.Column('gpu_memory_mb', sa.Integer(), nullable=True),
        sa.Column('input_payload', sa.JSON(), nullable=True),
        sa.Column('output_payload', sa.JSON(), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('submitted_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    )

    # ── mcp_audit_logs ──────────────────────────────────────────────────
    op.create_table('mcp_audit_logs',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('tool_name', sa.String(128), nullable=False),
        sa.Column('caller_token_hash', sa.String(256), nullable=False),
        sa.Column('request_payload', sa.JSON(), nullable=True),
        sa.Column('response_status', sa.Integer(), nullable=False),
        sa.Column('response_summary', sa.Text(), nullable=True),
        sa.Column('latency_ms', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('idx_mcp_audit_logs_caller', 'mcp_audit_logs', ['caller_token_hash'])
    op.create_index('idx_mcp_audit_logs_created', 'mcp_audit_logs', [sa.text('created_at DESC')])

    # ── model_runtime_states ────────────────────────────────────────────
    op.create_table('model_runtime_states',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('model_name', sa.String(128), unique=True, nullable=False),
        sa.Column('provider', sa.String(64), nullable=False),
        sa.Column('state', sa.String(16), nullable=False, server_default='idle'),
        sa.Column('gpu_memory_mb', sa.Integer(), nullable=True),
        sa.Column('last_heartbeat_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # ── reconciliation_events ───────────────────────────────────────────
    op.create_table('reconciliation_events',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('strategy_run_id', PG_UUID(as_uuid=True), sa.ForeignKey('strategy_runs.id'), nullable=True),
        sa.Column('freqtrade_run_id', PG_UUID(as_uuid=True), sa.ForeignKey('freqtrade_runs.id'), nullable=True),
        sa.Column('status', sa.String(16), nullable=False, server_default='started'),
        sa.Column('drift_summary', sa.JSON(), nullable=True),
        sa.Column('local_positions', sa.JSON(), nullable=True),
        sa.Column('remote_positions', sa.JSON(), nullable=True),
        sa.Column('started_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    )

    # ── freqtrade_connection_states ─────────────────────────────────────
    op.create_table('freqtrade_connection_states',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('freqtrade_run_id', PG_UUID(as_uuid=True), sa.ForeignKey('freqtrade_runs.id'), nullable=False),
        sa.Column('state', sa.String(48), nullable=False, server_default='healthy'),
        sa.Column('rest_status', sa.String(32), nullable=True),
        sa.Column('websocket_status', sa.String(32), nullable=True),
        sa.Column('docker_status', sa.String(32), nullable=True),
        sa.Column('open_positions_count', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('native_risk_ok', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('last_checked_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('idx_freqtrade_conn_state_run', 'freqtrade_connection_states', ['freqtrade_run_id'])

    # ── signal_archive_index ────────────────────────────────────────────
    op.create_table('signal_archive_index',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('signal_id', PG_UUID(as_uuid=True), nullable=False),
        sa.Column('archive_location', sa.String(512), nullable=False),
        sa.Column('original_created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('archived_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('idx_signal_archive_index_signal', 'signal_archive_index', ['signal_id'])

    # ── signal_reference_snapshots ──────────────────────────────────────
    op.create_table('signal_reference_snapshots',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('signal_id', PG_UUID(as_uuid=True), nullable=False),
        sa.Column('referenced_by_type', sa.String(64), nullable=False),
        sa.Column('referenced_by_id', PG_UUID(as_uuid=True), nullable=False),
        sa.Column('snapshot_data', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('idx_signal_ref_snapshots_signal', 'signal_reference_snapshots', ['signal_id'])

    # ── signal_archival_jobs ────────────────────────────────────────────
    op.create_table('signal_archival_jobs',
        sa.Column('id', PG_UUID(as_uuid=True), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('status', sa.String(16), nullable=False, server_default='pending'),
        sa.Column('criteria', sa.JSON(), nullable=True),
        sa.Column('signals_scanned', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('signals_archived', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    """Downgrade schema."""

    # ── Drop new tables (reverse order) ─────────────────────────────────
    op.drop_table('signal_archival_jobs')

    op.drop_index('idx_signal_ref_snapshots_signal', table_name='signal_reference_snapshots')
    op.drop_table('signal_reference_snapshots')

    op.drop_index('idx_signal_archive_index_signal', table_name='signal_archive_index')
    op.drop_table('signal_archive_index')

    op.drop_index('idx_freqtrade_conn_state_run', table_name='freqtrade_connection_states')
    op.drop_table('freqtrade_connection_states')

    op.drop_table('reconciliation_events')
    op.drop_table('model_runtime_states')

    op.drop_index('idx_mcp_audit_logs_created', table_name='mcp_audit_logs')
    op.drop_index('idx_mcp_audit_logs_caller', table_name='mcp_audit_logs')
    op.drop_table('mcp_audit_logs')

    op.drop_table('remote_model_jobs')

    op.drop_index('idx_inference_jobs_submitted', table_name='inference_jobs')
    op.drop_index('idx_inference_jobs_model_status', table_name='inference_jobs')
    op.drop_index('idx_inference_jobs_status', table_name='inference_jobs')
    op.drop_table('inference_jobs')

    # ── Remove added columns from portfolio_snapshots ───────────────────
    op.drop_index('idx_portfolio_snapshots_snapshot_at', table_name='portfolio_snapshots')
    op.drop_column('portfolio_snapshots', 'raw_payload')
    op.drop_column('portfolio_snapshots', 'open_positions_count')
    op.drop_column('portfolio_snapshots', 'max_drawdown_pct')
    op.drop_column('portfolio_snapshots', 'daily_pnl_pct')
    op.drop_column('portfolio_snapshots', 'total_exposure_pct')
    op.drop_column('portfolio_snapshots', 'available_cash')
    op.drop_column('portfolio_snapshots', 'total_equity')
    op.drop_column('portfolio_snapshots', 'snapshot_at')
    op.drop_column('portfolio_snapshots', 'capital_pool_id')
    op.drop_column('portfolio_snapshots', 'strategy_run_id')

    # ── Remove added columns from feature_snapshots ─────────────────────
    op.drop_index('idx_feature_snapshots_symbol', table_name='feature_snapshots')
    op.drop_column('feature_snapshots', 'trade_intent_id')
    op.drop_column('feature_snapshots', 'strategy_run_id')
    op.drop_column('feature_snapshots', 'data_quality')
    op.drop_column('feature_snapshots', 'portfolio_features')
    op.drop_column('feature_snapshots', 'manipulation_features')
    op.drop_column('feature_snapshots', 'onchain_features')
    op.drop_column('feature_snapshots', 'sentiment_features')
    op.drop_column('feature_snapshots', 'technical_features')
    op.drop_column('feature_snapshots', 'feature_version')
    op.drop_column('feature_snapshots', 'timeframe')
    op.drop_column('feature_snapshots', 'market')
    op.drop_column('feature_snapshots', 'symbol')
