"""Risk BFF schemas"""
from __future__ import annotations
from datetime import datetime
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class RiskGuard(BaseModel):
    key: str
    label: str
    current_value: float = 0
    limit_value: float = 0
    remaining_pct: float = 1.0
    status: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)


class RiskOverviewResponse(BaseModel):
    state: str = "normal"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    account_state: str = "normal"
    emergency_locked: bool = False
    guards: list[RiskGuard] = Field(default_factory=list)
    active_locks: list[dict] = Field(default_factory=list)


class StopLevel(BaseModel):
    raw_structure_stop: float | None = None
    last_known_good_stop: float | None = None
    secure_runtime_stop: float | None = None
    exchange_protective_stop: float | None = None
    volatility_locked: bool = False


class PositionStop(BaseModel):
    position_id: str
    symbol: str
    side: str
    entry_price: float
    current_price: float
    stops: StopLevel = Field(default_factory=StopLevel)
    stop_update_allowed: bool = True
    reason_codes: list[str] = Field(default_factory=list)


class StopProtectionResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    positions: list[PositionStop] = Field(default_factory=list)
    volatility_locks: list[dict] = Field(default_factory=list)


class CircuitBreakerRecord(BaseModel):
    id: str
    type: str  # emergency_stop / kill_switch / daily_loss_lock / weekly_loss_lock / manual_force_close / system_safe_mode
    account_id: str = ""
    strategy_id: str = ""
    reason_codes: list[str] = Field(default_factory=list)
    related_command_id: str | None = None
    related_reconciliation_id: str | None = None
    created_at: datetime | None = None


class CircuitBreakersResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    records: list[CircuitBreakerRecord] = Field(default_factory=list)
    total_count: int = 0
