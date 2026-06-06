"""live_small safety schemas — precondition checks, config preview, circuit breaker.

live_small is the only mode that touches real funds. These schemas enforce
safety invariants at the type level. No schema here triggers actual execution.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


# ── Precondition Check ────────────────────────────────────────────────

class PreconditionItem(BaseModel):
    name: str
    passed: bool
    reason: str = ""


class PreconditionReport(BaseModel):
    all_passed: bool = False
    items: list[PreconditionItem] = []
    strategy_version_id: Optional[uuid.UUID] = None
    capital_pool_id: Optional[uuid.UUID] = None


# ── Run History Stats (input to precondition checker) ─────────────────

class RunHistoryStats(BaseModel):
    strategy_version_status: str = "draft"
    backtest_count: int = 0
    dryrun_count: int = 0
    longest_dryrun_hours: float = 0.0
    dryrun_had_failure: bool = False
    has_risk_policy_binding: bool = False
    capital_pool_requires_human_confirm: bool = False
    active_live_small_run_exists: bool = False


# ── Capital Pool Params (subset for safety checks) ────────────────────

class CapitalPoolParams(BaseModel):
    total_budget: float = Field(gt=0)
    max_position_pct_per_trade: float = Field(gt=0, le=1.0, default=0.03)
    max_total_exposure_pct: float = Field(gt=0, le=1.0, default=0.30)
    max_daily_loss_pct: float = Field(gt=0, le=1.0, default=0.03)
    max_drawdown_pct: float = Field(gt=0, le=1.0, default=0.08)
    max_consecutive_losses: int = Field(ge=1, default=3)
    allow_leverage: Literal[False] = False
    allow_auto_trade: Literal[False] = False
    requires_human_confirm: Literal[True] = True
    currency: str = "USDT"


# ── Freqtrade Config Preview ─────────────────────────────────────────

class FreqtradeConfigPreview(BaseModel):
    dry_run: Literal[False] = False
    trading_mode: Literal["spot"] = "spot"
    stake_currency: str = "USDT"
    stake_amount: float = Field(gt=0)
    tradable_balance_ratio: float = 0.95
    max_open_trades: int = Field(ge=1)
    stoploss: float = Field(lt=0)
    trailing_stop: bool = False
    exchange_name: str = "binance"
    pair_whitelist: list[str] = []
    protections: list[dict[str, Any]] = []
    api_server_listen_ip: Literal["127.0.0.1"] = "127.0.0.1"


# ── Circuit Breaker ──────────────────────────────────────────────────

class CircuitBreakerResult(BaseModel):
    should_stop: bool = False
    reasons: list[str] = []
    daily_loss_pct: float = 0.0
    consecutive_losses: int = 0
    total_trades_today: int = 0


# ── Confirm Payload ──────────────────────────────────────────────────

class LiveSmallConfirmPayload(BaseModel):
    strategy_version_id: uuid.UUID
    capital_pool_id: uuid.UUID
    risk_policy_version_id: uuid.UUID
    human_confirmed: Literal[True] = True
    confirmed_by: str = Field(min_length=1)
    confirmed_at: datetime
    confirmation_checklist: dict[str, bool] = {}


# ── API Request / Response ────────────────────────────────────────────

class PreconditionCheckRequest(BaseModel):
    strategy_version_id: uuid.UUID
    capital_pool_id: uuid.UUID


class ConfigPreviewRequest(BaseModel):
    strategy_version_id: uuid.UUID
    capital_pool_id: uuid.UUID
    exchange_name: str = "binance"


class CircuitBreakerCheckRequest(BaseModel):
    strategy_run_id: uuid.UUID


class LiveSmallApprovalResponse(BaseModel):
    preconditions: PreconditionReport
    risk_check_passed: bool = False
    risk_errors: list[dict[str, str]] = []
    config_preview: Optional[FreqtradeConfigPreview] = None
    can_proceed: bool = False
    requires_human_confirm: Literal[True] = True
