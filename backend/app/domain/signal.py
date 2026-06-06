"""Signal Center — v2.5 ERD §3"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Numeric, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import func, JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class SignalIdentity(Base):
    __tablename__ = "signal_identity"

    id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Signal(Base):
    __tablename__ = "signals"

    id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)

    source_type: Mapped[str] = mapped_column(String(64), nullable=False)
    source_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    source_name: Mapped[str | None] = mapped_column(String(128))

    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    market: Mapped[str] = mapped_column(String(16), nullable=False, server_default="crypto")
    timeframe: Mapped[str | None] = mapped_column(String(8))

    direction: Mapped[str] = mapped_column(String(16), nullable=False)
    confidence: Mapped[float | None] = mapped_column(Numeric(6, 4))
    score: Mapped[float | None] = mapped_column(Numeric(8, 4))
    risk_level: Mapped[str | None] = mapped_column(String(16))

    status: Mapped[str] = mapped_column(String(16), nullable=False)
    permission: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)

    valid_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_signals_symbol_status_created", "symbol", "status", created_at.desc()),
    )


class SignalPayload(Base):
    __tablename__ = "signal_payloads"

    signal_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("signal_identity.id"), primary_key=True,
    )
    reasoning: Mapped[str | None] = mapped_column(Text)
    structured_output: Mapped[dict | None] = mapped_column(JSONB)
    raw_output: Mapped[dict | None] = mapped_column(JSONB)
    trigger_condition: Mapped[dict | None] = mapped_column(JSONB)
    current_state: Mapped[dict | None] = mapped_column(JSONB)
    evidence_summary: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SignalEvidence(UUIDMixin, Base):
    __tablename__ = "signal_evidence"

    signal_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("signal_identity.id"), nullable=False,
    )
    evidence_type: Mapped[str] = mapped_column(String(64), nullable=False)
    evidence_ref: Mapped[str | None] = mapped_column(String(256))
    evidence_payload: Mapped[dict | None] = mapped_column(JSONB)
    source_uri: Mapped[str | None] = mapped_column(String(512))
    quality_score: Mapped[float | None] = mapped_column(Numeric(6, 4))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SignalLifecycleEvent(UUIDMixin, Base):
    __tablename__ = "signal_lifecycle_events"

    signal_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("signal_identity.id"), nullable=False,
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    from_status: Mapped[str | None] = mapped_column(String(16))
    to_status: Mapped[str | None] = mapped_column(String(16))
    reason: Mapped[str | None] = mapped_column(Text)
    actor: Mapped[str | None] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SignalSnapshot(UUIDMixin, Base):
    __tablename__ = "signal_snapshots"

    signal_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("signal_identity.id"), nullable=False,
    )
    snapshot_reason: Mapped[str] = mapped_column(String(64), nullable=False)
    snapshot_payload: Mapped[dict] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
