"""Circuit Breaker Events — 熔断记录"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class CircuitBreakerEvent(UUIDMixin, Base):
    __tablename__ = "circuit_breaker_events"

    event_type: Mapped[str] = mapped_column(
        String(32), nullable=False,
    )  # emergency_stop / kill_switch / daily_loss_lock / weekly_loss_lock / manual_force_close / system_safe_mode

    account_id: Mapped[str] = mapped_column(String(64), nullable=False, server_default="default")
    strategy_id: Mapped[str | None] = mapped_column(String(64))
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    reason_codes: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    description: Mapped[str | None] = mapped_column(Text)

    related_command_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    related_reconciliation_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    triggered_by: Mapped[str] = mapped_column(String(32), nullable=False, server_default="system")  # system / manual / risk_engine
    resolved: Mapped[bool] = mapped_column(nullable=False, server_default="false")
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_cb_events_type_created", "event_type", "created_at"),
        Index("idx_cb_events_account", "account_id", "created_at"),
    )
