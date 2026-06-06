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
