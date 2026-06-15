"""Manipulation Case & Alert — lifecycle-tracked manipulation events."""
from __future__ import annotations

from datetime import datetime
from sqlalchemy import func, String, Text, DateTime, Float, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class ManipulationCase(UUIDMixin, Base):
    __tablename__ = "manipulation_cases"

    symbol: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    market: Mapped[str] = mapped_column(String(16), nullable=False, default="crypto")
    manipulation_type: Mapped[str] = mapped_column(String(32), nullable=False)
    lifecycle_stage: Mapped[str] = mapped_column(String(32), nullable=False, default="suspected")
    confidence: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    evidence: Mapped[dict | None] = mapped_column(JSONB)
    timeline: Mapped[list | None] = mapped_column(JSONB)
    outcome: Mapped[dict | None] = mapped_column(JSONB)
    similar_cases: Mapped[list | None] = mapped_column(JSONB)
    auto_discovered: Mapped[bool] = mapped_column(Boolean, default=True)
    source: Mapped[str] = mapped_column(String(32), default="rule_engine")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ManipulationAlert(UUIDMixin, Base):
    __tablename__ = "manipulation_alerts"

    case_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    alert_type: Mapped[str] = mapped_column(String(32), nullable=False)
    severity: Mapped[str] = mapped_column(String(16), nullable=False, default="info")
    title: Mapped[str] = mapped_column(Text, nullable=False)
    detail: Mapped[dict | None] = mapped_column(JSONB)
    trading_signal: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
