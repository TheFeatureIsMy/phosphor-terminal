"""Volatility Locks — 波动率锁定"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Numeric, Boolean, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class VolatilityLock(UUIDMixin, Base):
    __tablename__ = "volatility_locks"

    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    timeframe: Mapped[str] = mapped_column(String(8), nullable=False, server_default="5m")

    lock_type: Mapped[str] = mapped_column(
        String(32), nullable=False,
    )  # atr_spike / spread_spike / depth_void / orderbook_imbalance

    trigger_value: Mapped[float] = mapped_column(Numeric(20, 8), nullable=False)
    threshold_value: Mapped[float] = mapped_column(Numeric(20, 8), nullable=False)

    reason_codes: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")
    action_taken: Mapped[str] = mapped_column(String(32), nullable=False, server_default="lock_stop_update")

    active: Mapped[bool] = mapped_column(nullable=False, server_default="true")
    locked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        Index("idx_vol_lock_symbol_active", "symbol", "active"),
    )
