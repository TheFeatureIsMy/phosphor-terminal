"""Feature / Portfolio Snapshots — v2.5 ERD §8, §11."""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Integer, Numeric, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class FeatureSnapshot(Base):
    """分区表 — PARTITION BY RANGE (snapshot_at)"""
    __tablename__ = "feature_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    snapshot_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)

    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    market: Mapped[str | None] = mapped_column(String(16))
    exchange: Mapped[str | None] = mapped_column(String(32))
    timeframe: Mapped[str | None] = mapped_column(String(8))
    feature_version: Mapped[str] = mapped_column(String(16), nullable=False, server_default="2.5")

    technical_features: Mapped[dict | None] = mapped_column(JSONB)
    sentiment_features: Mapped[dict | None] = mapped_column(JSONB)
    onchain_features: Mapped[dict | None] = mapped_column(JSONB)
    manipulation_features: Mapped[dict | None] = mapped_column(JSONB)
    portfolio_features: Mapped[dict | None] = mapped_column(JSONB)

    structure_context: Mapped[dict | None] = mapped_column(JSONB)
    mtf_guard_context: Mapped[dict | None] = mapped_column(JSONB)
    ai_context: Mapped[dict | None] = mapped_column(JSONB)
    risk_context: Mapped[dict | None] = mapped_column(JSONB)
    liquidity_context: Mapped[dict | None] = mapped_column(JSONB)

    data_quality: Mapped[str | None] = mapped_column(String(16), server_default="complete")

    strategy_id: Mapped[str | None] = mapped_column(String(128))
    strategy_version_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id"),
    )
    runtime_snapshot_id: Mapped[str | None] = mapped_column(String(128))
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    trade_intent_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("trade_intents.id"),
    )

    __table_args__ = (
        Index("idx_feature_snapshots_symbol", "symbol"),
        Index("idx_feature_snapshots_trade_intent", "trade_intent_id"),
        Index("idx_feature_snapshots_runtime_snapshot", "runtime_snapshot_id"),
    )


class PortfolioSnapshot(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "portfolio_snapshots"

    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    capital_pool_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("capital_pools.id"),
    )
    snapshot_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    total_equity: Mapped[float | None] = mapped_column(Numeric(20, 8))
    available_cash: Mapped[float | None] = mapped_column(Numeric(20, 8))
    total_exposure_pct: Mapped[float | None] = mapped_column(Numeric(8, 6))
    daily_pnl_pct: Mapped[float | None] = mapped_column(Numeric(8, 6))
    max_drawdown_pct: Mapped[float | None] = mapped_column(Numeric(8, 6))
    open_positions_count: Mapped[int | None] = mapped_column(Integer, server_default="0")
    raw_payload: Mapped[dict | None] = mapped_column(JSONB)

    __table_args__ = (
        Index("idx_portfolio_snapshots_snapshot_at", snapshot_at.desc()),
    )
