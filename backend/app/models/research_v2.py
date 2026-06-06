"""AI Research v2 ORM models — ResearchReport / SignalCandidate / StrategyDraft.

Uses v2.5 patterns: UUID PK via UUIDMixin, Mapped[] typed columns.
"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Float, Integer, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class ResearchReport(UUIDMixin, Base):
    __tablename__ = "research_reports"

    run_id: Mapped[int] = mapped_column(Integer, ForeignKey("ai_research_runs.id"), nullable=False)
    symbol: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    market: Mapped[str] = mapped_column(String(16), nullable=False, server_default="crypto")
    timeframe: Mapped[str] = mapped_column(String(8), nullable=False, server_default="1d")
    rating: Mapped[str] = mapped_column(String(16), nullable=False)
    direction: Mapped[str] = mapped_column(String(16), nullable=False)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    risk_level: Mapped[str] = mapped_column(String(16), nullable=False)
    agent_opinions: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    summary: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    evidence: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    provider_trace_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_research_reports_run", "run_id"),
        Index("idx_research_reports_symbol_created", "symbol", created_at.desc()),
    )


class SignalCandidate(UUIDMixin, Base):
    __tablename__ = "signal_candidates"

    report_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("research_reports.id"), nullable=False,
    )
    symbol: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    direction: Mapped[str] = mapped_column(String(16), nullable=False)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    risk_level: Mapped[str] = mapped_column(String(16), nullable=False)
    reasoning: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    entry_logic: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    exit_logic: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    suggested_indicators: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    time_horizon: Mapped[str] = mapped_column(String(16), nullable=False, server_default="1d")
    can_live_trade: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    can_backtest: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    can_paper_trade: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    requires_human_confirm: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_signal_candidates_report", "report_id"),
    )


class StrategyDraft(UUIDMixin, Base):
    __tablename__ = "strategy_drafts"

    candidate_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("signal_candidates.id"), nullable=False,
    )
    report_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("research_reports.id"), nullable=False,
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    rule_dsl: Mapped[dict] = mapped_column(JSONB, nullable=False)
    dsl_valid: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    dsl_errors: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    dsl_warnings: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    source_type: Mapped[str] = mapped_column(String(32), nullable=False, server_default="ai_research")
    auto_execute: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    requires_human_confirm: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    provider_trace_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
    confirmed_strategy_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_strategy_drafts_candidate", "candidate_id"),
        Index("idx_strategy_drafts_report", "report_id"),
    )
