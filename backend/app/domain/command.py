"""Command Bus — v2.5 §14"""
import uuid
from datetime import datetime

from sqlalchemy import text, func, String, Text, Integer, Boolean, DateTime, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import text, func, JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class CommandBusCommand(UUIDMixin, Base):
    __tablename__ = "command_bus_commands"

    command_type: Mapped[str] = mapped_column(String(64), nullable=False)
    aggregate_type: Mapped[str] = mapped_column(String(64), nullable=False)
    aggregate_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False)

    status: Mapped[str] = mapped_column(String(24), nullable=False, server_default="pending")

    idempotency_key: Mapped[str] = mapped_column(String(512), nullable=False, unique=True)
    requested_by: Mapped[str] = mapped_column(String(128), nullable=False)

    locked_by: Mapped[str | None] = mapped_column(String(128))
    locked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_retries: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    next_retry_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    priority: Mapped[int] = mapped_column(Integer, nullable=False, default=100)
    timeout_sec: Mapped[int] = mapped_column(Integer, nullable=False, default=300)
    cancel_requested: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))

    correlation_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    causation_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    error_code: Mapped[str | None] = mapped_column(String(64))
    error_message: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        Index(
            "idx_command_bus_pending", "status", "priority", "created_at",
            postgresql_where="status IN ('pending','retry_waiting')",
        ),
        Index(
            "idx_command_bus_lock", "locked_by", "locked_at",
            postgresql_where="status = 'running'",
        ),
    )
