"""Signal Archival — v2.5 ERD §14."""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Integer, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class SignalArchiveIndex(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "signal_archive_index"

    signal_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    archive_location: Mapped[str] = mapped_column(String(512), nullable=False)
    original_created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    archived_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_signal_archive_index_signal", "signal_id"),
    )


class SignalReferenceSnapshot(UUIDMixin, Base):
    __tablename__ = "signal_reference_snapshots"

    signal_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    referenced_by_type: Mapped[str] = mapped_column(String(64), nullable=False)
    referenced_by_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    snapshot_data: Mapped[dict] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_signal_ref_snapshots_signal", "signal_id"),
    )


class SignalArchivalJob(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "signal_archival_jobs"

    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="pending")
    criteria: Mapped[dict | None] = mapped_column(JSONB)
    signals_scanned: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    signals_archived: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
