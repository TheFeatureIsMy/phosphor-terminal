"""MTF Guard Replay & Backtest Stats schemas."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class MTFGuardReplayEvent(BaseModel):
    """Single replay event from the MTF Guard during a backtest candle."""
    candle_index: int
    timestamp: Optional[str] = None
    symbol: str
    fast_timeframe: str
    slow_timeframe: str
    guard_state: str
    action: str
    reason_codes: list[str] = Field(default_factory=list)
    violation: dict[str, Any] = Field(default_factory=dict)
    price_close: Optional[float] = None
    trade_would_enter: bool = False
    entry_blocked: bool = False
    size_reduced: bool = False


class MTFGuardReplayResponse(BaseModel):
    """Full replay of MTF Guard events for a backtest run."""
    backtest_id: int
    total_events: int
    events: list[MTFGuardReplayEvent] = Field(default_factory=list)
    summary: MTFGuardReplaySummary | None = None


class MTFGuardReplaySummary(BaseModel):
    total_candles_evaluated: int = 0
    violations_detected: int = 0
    entries_blocked: int = 0
    sizes_reduced: int = 0
    reclaims_confirmed: int = 0
    structures_invalidated: int = 0
    false_breakouts_avoided: int = 0


# Fix forward reference
MTFGuardReplayResponse.model_rebuild()


class MTFGuardBacktestStatsResponse(BaseModel):
    """Response for GET /mtf-guard-stats."""
    id: uuid.UUID
    backtest_id: uuid.UUID
    strategy_id: uuid.UUID
    symbol: str
    blocked_entries_count: int = 0
    reduced_size_count: int = 0
    temporary_violation_count: int = 0
    reclaim_confirmed_count: int = 0
    invalidated_count: int = 0
    pnl_delta: Optional[float] = None
    max_drawdown_delta: Optional[float] = None
    false_breakout_avoided_count: int = 0
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
