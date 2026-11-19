"""Growth Engine — v2.5 ERD §12"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Boolean, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class GrowthReport(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "growth_reports"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    strategy_run_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id"),
    )
    strategy_version_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id"),
    )
    report_type: Mapped[str] = mapped_column(String(32), nullable=False)
    period_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    metrics: Mapped[dict | None] = mapped_column(JSONB)
    findings: Mapped[list | None] = mapped_column(JSONB)
    suggestions: Mapped[list | None] = mapped_column(JSONB)


class StrategyCandidate(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "strategy_candidates"

    source_growth_report_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("growth_reports.id"), nullable=False,
    )
    source_strategy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id"), nullable=False,
    )
    candidate_dsl: Mapped[dict] = mapped_column(JSONB, nullable=False)
    candidate_dsl_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, server_default="draft")
    rationale: Mapped[str | None] = mapped_column(Text)
    dsl_valid: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="0")
    dsl_errors: Mapped[list | None] = mapped_column(JSONB)
    auto_execute: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="0")
    confirmed_strategy_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategies_v2.id"),
    )
    confirmed_version_no: Mapped[int | None] = mapped_column(Integer)


class OrderAttribution(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "order_attributions"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    execution_order_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("execution_orders.id"), nullable=False,
    )
    strategy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id"), nullable=False,
    )
    rule_path: Mapped[str | None] = mapped_column(String(256))
    attribution_confidence: Mapped[str] = mapped_column(String(16), nullable=False, server_default="low")
from sqlalchemy import func, String, Text, Boolean, DateTime, ForeignKey, Integer
