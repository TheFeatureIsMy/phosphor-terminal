from __future__ import annotations

from datetime import datetime, timezone, timedelta
from typing import Literal, Optional

from pydantic import BaseModel, Field


class CandidateSignal(BaseModel):
    direction: Literal["long", "short"]
    intent: str = "open_position"
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    reason_codes: list[str] = Field(default_factory=list)


class IndicatorContext(BaseModel):
    values: dict[str, float] = Field(default_factory=dict)


class StructureContext(BaseModel):
    market_regime: str = "unknown"
    structure_score: int = Field(default=0, ge=0, le=100)
    sweep: Optional[dict] = None
    fvg: Optional[dict] = None
    order_block: Optional[dict] = None


class AIContext(BaseModel):
    cache_state: Literal["fresh", "soft_expired", "hard_expired", "missing"] = "missing"
    ai_risk_score: float = Field(default=0.0, ge=0.0, le=1.0)
    risk_flags: list[str] = Field(default_factory=list)
    valid_until: Optional[datetime] = None


class LiquidityExecutionContext(BaseModel):
    spread_pct: Optional[float] = None
    depth_score: Optional[float] = None
    liquidity_state: Literal["normal", "wide_spread", "thin_depth", "unknown"] = "unknown"
    liquidity_buffer: Optional[float] = None


class RiskContext(BaseModel):
    account_risk_state: Literal["allowed", "blocked", "cooldown"] = "allowed"
    risk_per_trade: float = 0.01
    daily_loss_remaining: Optional[float] = None
    weekly_loss_remaining: Optional[float] = None


class ExecutionPlan(BaseModel):
    decision: Literal["allow_trade", "reject_trade", "reduce_size", "manual_confirm"] = "reject_trade"
    entry_type: Literal["limit", "market"] = "limit"
    entry_price: Optional[float] = None
    stop_price: Optional[float] = None
    take_profit_1: Optional[float] = None
    take_profit_2: Optional[float] = None
    position_size: Optional[float] = None
    reject_reason: Optional[str] = None


def _default_valid_until() -> datetime:
    return datetime.now(timezone.utc) + timedelta(minutes=5)


class RuntimeDecisionSnapshot(BaseModel):
    snapshot_id: str
    strategy_id: str
    strategy_version: str = "1.0"
    exchange: str = "binance"
    symbol: str
    timeframe: str = "5m"
    generated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    valid_until: datetime = Field(default_factory=_default_valid_until)

    candidate_signal: CandidateSignal
    indicator_context: IndicatorContext = Field(default_factory=IndicatorContext)
    structure_context: StructureContext = Field(default_factory=StructureContext)
    ai_context: AIContext = Field(default_factory=AIContext)
    liquidity_execution_context: LiquidityExecutionContext = Field(default_factory=LiquidityExecutionContext)
    risk_context: RiskContext = Field(default_factory=RiskContext)
    execution_plan: ExecutionPlan

    reason_codes: list[str] = Field(default_factory=list)
    latency_ms: Optional[int] = None
