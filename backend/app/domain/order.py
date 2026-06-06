"""Execution Materialized Views — v2.5 ERD §11"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Numeric, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import func, JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class ExecutionOrder(UUIDMixin, Base):
    __tablename__ = "execution_orders"

    latest_ledger_event_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    freqtrade_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("freqtrade_runs.id"),
    )
    source_system: Mapped[str] = mapped_column(String(32), nullable=False)
    source_order_id: Mapped[str] = mapped_column(String(256), nullable=False)
    freqtrade_trade_id: Mapped[str | None] = mapped_column(String(256))
    exchange: Mapped[str] = mapped_column(String(32), nullable=False)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    side: Mapped[str] = mapped_column(String(8), nullable=False)
    order_type: Mapped[str | None] = mapped_column(String(16))
    price: Mapped[float | None] = mapped_column(Numeric(28, 12))
    amount: Mapped[float | None] = mapped_column(Numeric(28, 12))
    filled_amount: Mapped[float | None] = mapped_column(Numeric(28, 12))
    fee: Mapped[dict | None] = mapped_column(JSONB)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict | None] = mapped_column(JSONB)

    __table_args__ = (UniqueConstraint("source_system", "source_order_id"),)


class ExecutionTrade(UUIDMixin, Base):
    __tablename__ = "execution_trades"

    latest_ledger_event_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    freqtrade_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("freqtrade_runs.id"),
    )
    source_system: Mapped[str] = mapped_column(String(32), nullable=False)
    source_trade_id: Mapped[str] = mapped_column(String(256), nullable=False)
    exchange: Mapped[str] = mapped_column(String(32), nullable=False)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    side: Mapped[str | None] = mapped_column(String(8))
    open_rate: Mapped[float | None] = mapped_column(Numeric(28, 12))
    close_rate: Mapped[float | None] = mapped_column(Numeric(28, 12))
    amount: Mapped[float | None] = mapped_column(Numeric(28, 12))
    profit_abs: Mapped[float | None] = mapped_column(Numeric(28, 12))
    profit_pct: Mapped[float | None] = mapped_column(Numeric(12, 6))
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict | None] = mapped_column(JSONB)

    __table_args__ = (UniqueConstraint("source_system", "source_trade_id"),)


class ExecutionPosition(UUIDMixin, Base):
    __tablename__ = "execution_positions"

    latest_ledger_event_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    exchange: Mapped[str] = mapped_column(String(32), nullable=False)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    position_side: Mapped[str | None] = mapped_column(String(8))
    amount: Mapped[float | None] = mapped_column(Numeric(28, 12))
    entry_price: Mapped[float | None] = mapped_column(Numeric(28, 12))
    mark_price: Mapped[float | None] = mapped_column(Numeric(28, 12))
    unrealized_pnl: Mapped[float | None] = mapped_column(Numeric(28, 12))
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict | None] = mapped_column(JSONB)

    __table_args__ = (UniqueConstraint("strategy_run_id", "exchange", "symbol", "position_side"),)


class OrderFill(UUIDMixin, Base):
    __tablename__ = "order_fills"

    execution_order_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("execution_orders.id"), nullable=False,
    )
    source_fill_id: Mapped[str | None] = mapped_column(String(256))
    price: Mapped[float] = mapped_column(Numeric(28, 12), nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(28, 12), nullable=False)
    fee: Mapped[dict | None] = mapped_column(JSONB)
    filled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    raw_payload: Mapped[dict | None] = mapped_column(JSONB)
