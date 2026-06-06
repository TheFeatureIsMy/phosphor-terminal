"""AI Research v2 schemas — ResearchReport / SignalCandidate / StrategyDraft.

Per ADR-001: only JSON DSL; no Python generation.
Per Phase 04: AI Research is read-only; no direct trading.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

from app.domain.enums import SignalDirection, SignalRiskLevel


# ── Agent Opinion ─────────────────────────────────────────────────────

class AgentOpinion(BaseModel):
    role: str
    stance: str  # bullish | bearish | neutral | cautious
    reasoning: str
    confidence: float = Field(ge=0, le=1)
    key_factors: list[str] = []


# ── ResearchReport ────────────────────────────────────────────────────

class ResearchReportData(BaseModel):
    report_id: uuid.UUID = Field(default_factory=uuid.uuid4)
    symbol: str
    market: str = "crypto"
    timeframe: str = "1d"
    rating: str  # Buy | Overweight | Hold | Underweight | Sell
    direction: SignalDirection
    confidence: float = Field(ge=0, le=1)
    risk_level: SignalRiskLevel
    agent_opinions: dict[str, AgentOpinion] = {}
    summary: str = ""
    evidence: list[str] = []
    provider_trace_id: Optional[uuid.UUID] = None
    created_at: Optional[datetime] = None


class ResearchReportResponse(BaseModel):
    id: uuid.UUID
    run_id: int
    symbol: str
    market: str
    timeframe: str
    rating: str
    direction: str
    confidence: float
    risk_level: str
    agent_opinions: dict[str, Any] = {}
    summary: str
    evidence: list[str] = []
    provider_trace_id: Optional[uuid.UUID] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── SignalCandidate ───────────────────────────────────────────────────

class SignalCandidateData(BaseModel):
    candidate_id: uuid.UUID = Field(default_factory=uuid.uuid4)
    report_id: uuid.UUID
    symbol: str
    direction: SignalDirection
    confidence: float = Field(ge=0, le=1)
    risk_level: SignalRiskLevel
    reasoning: str = ""
    entry_logic: str = ""
    exit_logic: str = ""
    suggested_indicators: list[str] = []
    time_horizon: str = "1d"
    can_live_trade: Literal[False] = False
    can_backtest: bool = True
    can_paper_trade: bool = True
    requires_human_confirm: Literal[True] = True


class SignalCandidateResponse(BaseModel):
    id: uuid.UUID
    report_id: uuid.UUID
    symbol: str
    direction: str
    confidence: float
    risk_level: str
    reasoning: str
    entry_logic: str
    exit_logic: str
    suggested_indicators: list[str] = []
    time_horizon: str
    can_live_trade: bool
    can_backtest: bool
    can_paper_trade: bool
    requires_human_confirm: bool
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── StrategyDraft ─────────────────────────────────────────────────────

class StrategyDraftData(BaseModel):
    draft_id: uuid.UUID = Field(default_factory=uuid.uuid4)
    candidate_id: uuid.UUID
    report_id: uuid.UUID
    name: str
    description: str = ""
    rule_dsl: dict[str, Any] = {}
    dsl_valid: bool = False
    dsl_errors: list[dict[str, Any]] = []
    dsl_warnings: list[dict[str, Any]] = []
    source_type: Literal["ai_research"] = "ai_research"
    auto_execute: Literal[False] = False
    requires_human_confirm: Literal[True] = True
    provider_trace_id: Optional[uuid.UUID] = None
    created_at: Optional[datetime] = None


class StrategyDraftResponse(BaseModel):
    id: uuid.UUID
    candidate_id: uuid.UUID
    report_id: uuid.UUID
    name: str
    description: str
    rule_dsl: dict[str, Any] = {}
    dsl_valid: bool
    dsl_errors: list[dict[str, Any]] = []
    dsl_warnings: list[dict[str, Any]] = []
    source_type: str
    auto_execute: bool
    requires_human_confirm: bool
    provider_trace_id: Optional[uuid.UUID] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ── API Requests ──────────────────────────────────────────────────────

class ResearchRunCreateV2(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=64)
    market: str = "crypto"
    timeframe: str = "1d"
    analysis_date: date
    selected_analysts: list[str] = [
        "market", "social", "news", "fundamentals",
    ]
    llm_provider: str = "openai"
    deep_think_llm: str = "gpt-5.4"
    quick_think_llm: str = "gpt-5.4-mini"
    max_debate_rounds: int = Field(default=1, ge=1, le=5)
    max_risk_rounds: int = Field(default=1, ge=1, le=5)


class GenerateDraftRequest(BaseModel):
    name_hint: Optional[str] = Field(
        default=None, max_length=128,
        description="Optional strategy name; auto-generated if omitted",
    )


class ConfirmDraftResponse(BaseModel):
    strategy_id: uuid.UUID
    version_id: uuid.UUID
    version_no: int
    status: str = "draft"
