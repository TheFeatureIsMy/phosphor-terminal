"""Overview BFF schemas — Dashboard + Live Readiness + Global Status"""
from __future__ import annotations
from datetime import datetime
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class AccountOverview(BaseModel):
    equity: float = 0
    currency: str = "USDT"
    today_pnl_pct: float = 0
    week_pnl_pct: float = 0
    max_drawdown_pct: float = 0


class RuntimeOverview(BaseModel):
    running_strategies: int = 0
    open_positions: int = 0
    pending_orders: int = 0
    reconciling_count: int = 0


class RiskOverview(BaseModel):
    global_state: str = "normal"
    daily_loss_remaining_pct: float = 0
    weekly_loss_remaining_pct: float = 0
    emergency_locked: bool = False
    reason_codes: list[str] = Field(default_factory=list)


class SystemOverview(BaseModel):
    live_readiness_state: str = "NOT_READY"
    fast_track_latency_ms: int = 0
    redis_rtt_ms: int = 0
    freqtrade_state: str = "unknown"
    exchange_state: str = "unknown"


class RecentDecision(BaseModel):
    time: datetime | None = None
    symbol: str = ""
    decision: str = ""
    reason_codes: list[str] = Field(default_factory=list)


class Alert(BaseModel):
    level: str = "info"
    title: str = ""
    symbol: str = ""
    time: datetime | None = None


class DashboardResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    account: AccountOverview = Field(default_factory=AccountOverview)
    runtime: RuntimeOverview = Field(default_factory=RuntimeOverview)
    risk: RiskOverview = Field(default_factory=RiskOverview)
    system: SystemOverview = Field(default_factory=SystemOverview)
    recent_decisions: list[RecentDecision] = Field(default_factory=list)
    alerts: list[Alert] = Field(default_factory=list)


class ReadinessCheck(BaseModel):
    key: str
    label: str
    status: str = "unknown"  # healthy / warning / failed / unknown
    value: str = ""
    threshold: str = ""


class LiveReadinessResponse(BaseModel):
    state: str = "NOT_READY"
    score: int = 0
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    can_start_paper: bool = False
    can_start_live_small: bool = False
    can_start_full_live: bool = False
    blocking_reasons: list[dict] = Field(default_factory=list)
    warnings: list[dict] = Field(default_factory=list)
    checks: list[ReadinessCheck] = Field(default_factory=list)


class GlobalStatusResponse(BaseModel):
    system_state: str = "NOT_READY"
    risk_state: str = "normal"
    fast_track_latency_ms: int = 0
    freqtrade_state: str = "unknown"
    redis_rtt_ms: int = 0
    exchange_state: str = "unknown"
    open_positions: int = 0
    emergency_locked: bool = False
    reason_codes: list[str] = Field(default_factory=list)
