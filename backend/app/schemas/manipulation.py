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


# ---- v2: Narrative Refactor Schemas ----

class EvidenceLayerFeature(BaseModel):
    name: str
    value: float = 0.0
    percentile: float | None = None
    zscore: float | None = None


class EvidenceLayer(BaseModel):
    available: bool = False
    data_quality: float = 0.0
    score: float | None = None
    features: list[EvidenceLayerFeature] = []
    reason: str | None = None


class EvidenceLayersBlock(BaseModel):
    A_price: EvidenceLayer | None = None
    B_orderbook: EvidenceLayer | None = None
    C_onchain: EvidenceLayer | None = None
    D_social: EvidenceLayer | None = None
    E_cross_market: EvidenceLayer | None = None


class DualTradingSignal(BaseModel):
    conservative: TradingSignalResponse = TradingSignalResponse()
    aggressive: TradingSignalResponse = TradingSignalResponse()


class CaseDetailV2(BaseModel):
    id: str = ""
    symbol: str = ""
    market: str = "crypto"
    manipulation_type: str = ""
    lifecycle_stage: str = "suspected"
    confidence: float = 0.0
    risk_level: str = "medium"
    evidence: dict = {}
    evidence_layers: EvidenceLayersBlock | None = None
    completeness: float = 0.0
    max_confidence: float = 1.0
    timeline: list[LifecycleStageInfo] = []
    trading_signal: DualTradingSignal | None = None
    affected_symbols: list[str] = []
    sources: list[dict] = []
    outcome: dict = {}
    auto_discovered: bool = True
    source: str = "rule_engine"
    created_at: str = ""
    updated_at: str = ""
    completed_at: str | None = None


class ManipulationFilterStatus(BaseModel):
    enabled: bool = False
    would_block: bool = False
    reason_codes: list[str] = []


class AffectedStrategy(BaseModel):
    strategy_id: str = ""
    name: str = ""
    matches_symbols: list[str] = []
    manipulation_filter: ManipulationFilterStatus = ManipulationFilterStatus()


class StrategyImpactResponse(BaseModel):
    case_id: str = ""
    affected_strategies: list[AffectedStrategy] = []
    total_affected: int = 0
    total_protected: int = 0


class SimilarCaseItem(BaseModel):
    id: str = ""
    symbol: str = ""
    manipulation_type: str = ""
    similarity: float = 0.0
    outcome: dict = {}
    completed_at: str | None = None


class SimilarCasesResponse(BaseModel):
    case_id: str = ""
    similar: list[SimilarCaseItem] = []
    total: int = 0
