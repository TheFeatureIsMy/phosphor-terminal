"""Execution Ledger — v2.5 §15 (append-only, immutable fact source)"""
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint,
    event, func, select,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class ExecutionLedgerEvent(Base):
    __tablename__ = "execution_ledger_events"

    id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)

    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    source_system: Mapped[str] = mapped_column(String(32), nullable=False)
    source_event_id: Mapped[str | None] = mapped_column(String(256))
    event_hash: Mapped[str] = mapped_column(String(128), nullable=False)

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    freqtrade_run_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    command_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    trade_intent_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    risk_decision_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    symbol: Mapped[str | None] = mapped_column(String(32))
    sequence_no: Mapped[int | None] = mapped_column(BigInteger)
    schema_version: Mapped[str] = mapped_column(String(8), nullable=False, server_default="2.5")

    correlation_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    causation_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    raw_payload: Mapped[dict | None] = mapped_column(JSONB)
    normalized_payload: Mapped[dict] = mapped_column(JSONB, nullable=False)

    ingested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("event_hash", "event_time", name="uq_ledger_event_hash"),
        Index("idx_ledger_source_event", "source_system", "source_event_id", "event_type", "event_time", unique=True, sqlite_where=None),
        Index("idx_ledger_correlation", "correlation_id", "event_time"),
        Index("idx_ledger_strategy_run", "strategy_run_id", "event_time"),
        Index("idx_ledger_command", "command_id", "event_time"),
        Index("idx_ledger_event_type", "event_type", "event_time"),
        Index("idx_ledger_symbol", "symbol", "event_time"),
    )


@event.listens_for(ExecutionLedgerEvent, "before_insert")
def _fill_tenant_from_run(mapper, connection, target) -> None:
    """Derive tenant_id from the event's strategy run when not supplied."""
    if target.tenant_id is not None or target.strategy_run_id is None:
        return
    from app.domain.execution import StrategyRun
    from app.domain.strategy import StrategyVersion

    target.tenant_id = connection.execute(
        select(StrategyVersion.tenant_id)
        .select_from(StrategyRun)
        .join(StrategyVersion, StrategyVersion.id == StrategyRun.strategy_version_id)
        .where(StrategyRun.id == target.strategy_run_id)
    ).scalar()
