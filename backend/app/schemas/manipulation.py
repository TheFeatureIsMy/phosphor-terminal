"""Manipulation Radar schemas."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class ManipulationScanRequest(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=32)
    timeframe: str = Field(default="1h", max_length=8)


class ManipulationScoreResponse(BaseModel):
    id: uuid.UUID
    symbol: str
    timeframe: str
    manipulation_score: float
    stop_hunt_score: float
    pump_dump_score: float
    liquidity_trap_score: float
    holder_concentration_score: float
    funding_squeeze_score: float
    risk_level: str
    reasoning: Optional[str] = None
    data_quality: Optional[dict[str, Any]] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_model(cls, obj: Any) -> "ManipulationScoreResponse":
        scores = obj.scores or {}
        return cls(
            id=obj.id,
            symbol=obj.symbol,
            timeframe=obj.timeframe,
            manipulation_score=scores.get("manipulation_score", 0),
            stop_hunt_score=scores.get("stop_hunt_score", 0),
            pump_dump_score=scores.get("pump_dump_score", 0),
            liquidity_trap_score=scores.get("liquidity_trap_score", 0),
            holder_concentration_score=scores.get("holder_concentration_score", 0),
            funding_squeeze_score=scores.get("funding_squeeze_score", 0),
            risk_level=obj.risk_level,
            reasoning=obj.reasoning,
            data_quality=obj.data_quality,
            created_at=obj.created_at,
        )

# ---- Lifecycle Engine Schemas ----

class LifecycleStageInfo(BaseModel):
    stage: str = "suspected"
    entered_at: str = ""
    confidence: float = 0.0
    features_snapshot: dict = {}

class TradingSignalResponse(BaseModel):
    action: str = ""          # AMBUSH / RIDE / EXIT_OR_SHORT / AVOID / WATCH / CAUTION / EXIT
    direction: str = "none"   # long / short / none
    sizing: str = ""          # small / medium / reduce / none
    stop_loss: str = ""       # tight / trailing / none
    rationale: str = ""
    risk_level: str = "high"

class ManipulationCaseResponse(BaseModel):
    id: str = ""
    symbol: str = ""
    market: str = "crypto"
    manipulation_type: str = ""
    lifecycle_stage: str = "suspected"
    confidence: float = 0.0
    evidence: dict = {}
    timeline: list[LifecycleStageInfo] = []
    outcome: dict = {}
    similar_cases: list[str] = []
    auto_discovered: bool = True
    source: str = "rule_engine"
    trading_signal: TradingSignalResponse = TradingSignalResponse()
    created_at: str = ""
    updated_at: str = ""

class ManipulationCaseSummary(BaseModel):
    id: str = ""
    symbol: str = ""
    manipulation_type: str = ""
    lifecycle_stage: str = "suspected"
    confidence: float = 0.0
    trading_signal_action: str = ""
    created_at: str = ""

class ManipulationAlertResponse(BaseModel):
    id: str = ""
    case_id: str = ""
    alert_type: str = ""
    severity: str = "info"
    title: str = ""
    detail: dict = {}
    trading_signal: TradingSignalResponse | None = None
    created_at: str = ""

class ManipulationRadarOverview(BaseModel):
    active_cases: list[ManipulationCaseSummary] = []
    total_active: int = 0
    by_stage: dict[str, int] = {}
    high_risk_symbols: list[str] = []
    recent_alerts: list[ManipulationAlertResponse] = []
