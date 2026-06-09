"""MTF Temporal Guard — §6 跨周期结构防御"""
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import func, String, Boolean, Integer, Numeric, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class MTFGuardEvent(UUIDMixin, Base):
    __tablename__ = "mtf_guard_events"

    strategy_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    strategy_version_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    exchange: Mapped[str | None] = mapped_column(String(32))
    fast_timeframe: Mapped[str] = mapped_column(String(8), nullable=False)
    slow_timeframe: Mapped[str] = mapped_column(String(8), nullable=False)
    structure_type: Mapped[str] = mapped_column(String(32), nullable=False)
    structure_id: Mapped[str | None] = mapped_column(String(64))
    guard_state: Mapped[str] = mapped_column(String(32), nullable=False)
    action: Mapped[str] = mapped_column(String(32), nullable=False)
    low_tf_price: Mapped[Decimal | None] = mapped_column(Numeric())
    htf_zone_top: Mapped[Decimal | None] = mapped_column(Numeric())
    htf_zone_bottom: Mapped[Decimal | None] = mapped_column(Numeric())
    htf_candle_closed: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    reason_codes: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")
    snapshot_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_mtf_guard_events_strategy", "strategy_id", "symbol"),
        Index("idx_mtf_guard_events_created", "created_at"),
    )


class MTFGuardBacktestStats(UUIDMixin, Base):
    __tablename__ = "mtf_guard_backtest_stats"

    backtest_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    strategy_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    blocked_entries_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    reduced_size_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    temporary_violation_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    reclaim_confirmed_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    invalidated_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    pnl_delta: Mapped[Decimal | None] = mapped_column(Numeric())
    max_drawdown_delta: Mapped[Decimal | None] = mapped_column(Numeric())
    false_breakout_avoided_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
