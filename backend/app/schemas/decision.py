from __future__ import annotations
from typing import Any, Optional
from pydantic import BaseModel


class EvaluateRequest(BaseModel):
    strategy_id: str
    dsl: dict[str, Any]
    account_id: str
    exchange: str = "binance"
    symbol: str
    timeframe: str = "5m"


class SnapshotResponse(BaseModel):
    snapshot_id: str
    strategy_id: str
    symbol: str
    timeframe: str
    decision: str
    reason_codes: list[str]
    execution_plan: dict[str, Any]
    generated_at: str
    valid_until: str


class RiskStateResponse(BaseModel):
    allowed: bool
    decision: str
    reason_code: str
    daily_pnl: float
    weekly_pnl: float
    consecutive_losses: int


class KillSwitchRequest(BaseModel):
    activate: bool = True
