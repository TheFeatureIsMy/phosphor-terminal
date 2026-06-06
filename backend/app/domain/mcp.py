"""MCP Audit & Model Runtime — v2.5 ERD §13."""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Integer, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class McpAuditLog(UUIDMixin, Base):
    __tablename__ = "mcp_audit_logs"

    tool_name: Mapped[str] = mapped_column(String(128), nullable=False)
    caller_token_hash: Mapped[str] = mapped_column(String(256), nullable=False)
    request_payload: Mapped[dict | None] = mapped_column(JSONB)
    response_status: Mapped[int] = mapped_column(Integer, nullable=False)
    response_summary: Mapped[str | None] = mapped_column(Text)
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_mcp_audit_logs_caller", "caller_token_hash"),
        Index("idx_mcp_audit_logs_created", created_at.desc()),
    )


class ModelRuntimeState(UUIDMixin, Base):
    __tablename__ = "model_runtime_states"

    model_name: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    provider: Mapped[str] = mapped_column(String(64), nullable=False)
    state: Mapped[str] = mapped_column(String(16), nullable=False, server_default="idle")
    gpu_memory_mb: Mapped[int | None] = mapped_column(Integer)
    last_heartbeat_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(),
    )
