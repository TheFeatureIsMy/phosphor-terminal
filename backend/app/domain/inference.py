"""Inference & Remote Model Jobs — v2.5 ERD §12."""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Integer, Numeric, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class InferenceJob(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "inference_jobs"

    job_type: Mapped[str] = mapped_column(String(64), nullable=False)
    model_name: Mapped[str] = mapped_column(String(128), nullable=False)
    provider_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("ai_provider_configs.id"),
    )
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="queued")

    input_payload: Mapped[dict | None] = mapped_column(JSONB)
    output_payload: Mapped[dict | None] = mapped_column(JSONB)
    error_message: Mapped[str | None] = mapped_column(Text)

    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    timeout_sec: Mapped[int] = mapped_column(Integer, nullable=False, server_default="300")
    estimated_cost_usd: Mapped[float | None] = mapped_column(Numeric(12, 6))
    actual_cost_usd: Mapped[float | None] = mapped_column(Numeric(12, 6))

    __table_args__ = (
        Index("idx_inference_jobs_status", "status"),
        Index("idx_inference_jobs_model_status", "model_name", "status"),
        Index("idx_inference_jobs_submitted", submitted_at.desc()),
    )


class RemoteModelJob(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "remote_model_jobs"

    model_name: Mapped[str] = mapped_column(String(128), nullable=False)
    provider: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="queued")
    gpu_memory_mb: Mapped[int | None] = mapped_column(Integer)

    input_payload: Mapped[dict | None] = mapped_column(JSONB)
    output_payload: Mapped[dict | None] = mapped_column(JSONB)
    error_message: Mapped[str | None] = mapped_column(Text)

    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
