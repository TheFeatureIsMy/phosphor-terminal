"""TradeIntent / RiskDecision — v2.5 ERD §8"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import func, JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class TradeIntent(UUIDMixin, Base):
    __tablename__ = "trade_intents"

    intent_type: Mapped[str] = mapped_column(String(32), nullable=False)
    strategy_run_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"), nullable=False,
    )
    strategy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id"), nullable=False,
    )
    feature_snapshot_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    side: Mapped[str] = mapped_column(String(8), nullable=False)
    requested_position_pct: Mapped[float | None] = mapped_column(Numeric(8, 4))
    mode: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="created")
    reasoning: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TradeIntentSignalSnapshot(UUIDMixin, Base):
    __tablename__ = "trade_intent_signal_snapshots"

    trade_intent_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("trade_intents.id"), nullable=False,
    )
    signal_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("signal_identity.id"), nullable=False,
    )
    signal_status_at_trigger: Mapped[str | None] = mapped_column(String(16))
    direction: Mapped[str | None] = mapped_column(String(16))
    confidence: Mapped[float | None] = mapped_column(Numeric(6, 4))
    score: Mapped[float | None] = mapped_column(Numeric(8, 4))
    reasoning_snapshot: Mapped[str | None] = mapped_column(Text)
    evidence_snapshot: Mapped[dict | None] = mapped_column(JSONB)
    provider_trace_snapshot: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RiskDecision(UUIDMixin, Base):
    __tablename__ = "risk_decisions"

    trade_intent_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("trade_intents.id"),
    )
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    decision: Mapped[str] = mapped_column(String(32), nullable=False)
    final_position_pct: Mapped[float | None] = mapped_column(Numeric(8, 4))
    risk_checks: Mapped[dict] = mapped_column(JSONB, nullable=False)
    risk_codes: Mapped[list | None] = mapped_column(JSONB)
    reasoning: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
