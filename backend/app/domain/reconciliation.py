"""Reconciliation & Connection State — v2.5 ERD §9."""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Integer, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class ReconciliationEvent(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "reconciliation_events"

    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    freqtrade_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("freqtrade_runs.id"),
    )
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="started")

    drift_summary: Mapped[dict | None] = mapped_column(JSONB)
    local_positions: Mapped[dict | None] = mapped_column(JSONB)
    remote_positions: Mapped[dict | None] = mapped_column(JSONB)

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class FreqtradeConnectionState(UUIDMixin, Base):
    __tablename__ = "freqtrade_connection_states"

    freqtrade_run_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("freqtrade_runs.id"), nullable=False,
    )
    state: Mapped[str] = mapped_column(String(48), nullable=False, server_default="healthy")
    rest_status: Mapped[str | None] = mapped_column(String(32))
    websocket_status: Mapped[str | None] = mapped_column(String(32))
    docker_status: Mapped[str | None] = mapped_column(String(32))
    open_positions_count: Mapped[int | None] = mapped_column(Integer, server_default="0")
    native_risk_ok: Mapped[bool | None] = mapped_column(Boolean, server_default="true")
    last_checked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_freqtrade_conn_state_run", "freqtrade_run_id"),
    )
