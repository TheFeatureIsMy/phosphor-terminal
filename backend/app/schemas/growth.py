"""Growth Engine schemas — GrowthReport / TradeMetrics / StrategyCandidate.

Growth Engine is read-only over execution data. It generates reports and
strategy candidates but never modifies running strategies or triggers execution.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


# ── Trade Metrics ─────────────────────────────────────────────────────

class TradeMetrics(BaseModel):
    total_trades: int = 0
    win_count: int = 0
    loss_count: int = 0
    breakeven_count: int = 0
    win_rate: float = 0.0
    total_pnl: float = 0.0
    avg_profit_pct: float = 0.0
    avg_loss_pct: float = 0.0
    max_drawdown_pct: float = 0.0
    best_trade_pct: float = 0.0
    worst_trade_pct: float = 0.0
    avg_hold_duration_hours: float = 0.0
    profit_factor: float = 0.0
    symbols_traded: list[str] = []


# ── Finding ───────────────────────────────────────────────────────────

class Finding(BaseModel):
    category: str  # strength | weakness | pattern | risk
    description: str
    evidence: dict[str, Any] = {}


# ── GrowthReport ──────────────────────────────────────────────────────

class GrowthReportData(BaseModel):
    report_type: str  # daily_review | run_review
    strategy_run_id: Optional[uuid.UUID] = None
    strategy_version_id: Optional[uuid.UUID] = None
    period_start: datetime
    period_end: datetime
    metrics: TradeMetrics
    findings: list[Finding] = []
    suggestions: list[str] = []


class GrowthReportResponse(BaseModel):
    id: uuid.UUID
    report_type: str
    strategy_run_id: Optional[uuid.UUID] = None
    strategy_version_id: Optional[uuid.UUID] = None
    period_start: Optional[datetime] = None
    period_end: Optional[datetime] = None
    metrics: dict[str, Any] = {}
    findings: dict[str, Any] | list[Any] | None = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── StrategyCandidate ─────────────────────────────────────────────────

class StrategyCandidateData(BaseModel):
    source_growth_report_id: uuid.UUID
    source_strategy_version_id: uuid.UUID
    candidate_dsl: dict[str, Any]
    candidate_dsl_hash: str = ""
    rationale: str = ""
    dsl_valid: bool = False
    dsl_errors: list[dict[str, Any]] = []
    auto_execute: Literal[False] = False
    status: str = "draft"


class StrategyCandidateResponse(BaseModel):
    id: uuid.UUID
    source_growth_report_id: Optional[uuid.UUID] = None
    source_strategy_version_id: Optional[uuid.UUID] = None
    candidate_dsl: dict[str, Any] = {}
    candidate_dsl_hash: str = ""
    status: str
    rationale: Optional[str] = None
    dsl_valid: bool = False
    dsl_errors: list[dict[str, Any]] = []
    auto_execute: bool = False
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── API Requests ──────────────────────────────────────────────────────

class RunReviewRequest(BaseModel):
    strategy_run_id: uuid.UUID


class DailyReviewRequest(BaseModel):
    days: int = Field(default=1, ge=1, le=30)


class GenerateCandidateRequest(BaseModel):
    name_hint: Optional[str] = Field(default=None, max_length=128)


class ConfirmCandidateResponse(BaseModel):
    strategy_id: uuid.UUID
    version_id: uuid.UUID
    version_no: int
    status: str = "draft"
