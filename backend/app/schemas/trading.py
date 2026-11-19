"""Trading control schemas — start-paper / start-live-small / disable-auto.

Responses follow the unified BFF state model (state + reason_codes +
available_actions). These endpoints are the execution entry points demanded
by the PRD Live Readiness page; start-live-small is gated by the full
live_small safety chain plus the LIVE_SMALL_ENABLED deployment switch.
"""
from __future__ import annotations

import uuid
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.live_small import (
    CircuitBreakerResult,
    FreqtradeConfigPreview,
    PreconditionReport,
)


# ── Requests ──────────────────────────────────────────────────────────

class StartPaperRequest(BaseModel):
    strategy_version_id: uuid.UUID
    symbols: list[str] = Field(default=["BTC/USDT"], min_length=1)
    stake_amount: float = Field(default=100, gt=0)
    max_open_trades: int = Field(default=5, ge=1)
    initial_wallet: float = Field(default=10000, gt=0)
    exchange: str = "binance"
    api_port: int = Field(default=8080, ge=1024, le=65535)
    client_request_id: Optional[str] = Field(default=None, max_length=80)


class StartLiveSmallRequest(BaseModel):
    strategy_version_id: uuid.UUID
    capital_pool_id: uuid.UUID
    exchange_name: str = "binance"
    human_confirmed: bool = False
    confirmed_by: str = ""


class DisableAutoRequest(BaseModel):
    reason: str = "manual_disable"


# ── Responses ─────────────────────────────────────────────────────────

class DemoBalance(BaseModel):
    currency: str
    balance: float


class DemoProcessResponse(BaseModel):
    """The Freqtrade process on the demo port. No API keys."""

    reachable: bool
    state: str
    strategy: str | None = None
    timeframe: str | None = None
    trading_mode: str | None = None
    dry_run: bool | None = None
    exchange: str | None = None
    venue: str = "freqtrade"
    rest_hosts: list[str] = []
    stake_currency: str | None = None
    stake_amount: str | None = None
    max_open_trades: int | None = None
    open_trades: int = 0
    closed_trades: int = 0
    total: float | None = None
    balances: list[DemoBalance] = []


class TradingCommandResponse(BaseModel):
    state: str
    reason_codes: list[str] = []
    available_actions: list[dict] = []
    command_id: Optional[uuid.UUID] = None
    command_status: Optional[str] = None
    idempotency_key: Optional[str] = None
    message: str = ""


class StartLiveSmallResponse(BaseModel):
    state: str  # approved_enqueued / blocked / waiting_confirmation / not_enabled
    reason_codes: list[str] = []
    available_actions: list[dict] = []
    command_id: Optional[uuid.UUID] = None
    command_status: Optional[str] = None
    can_proceed: bool = False
    live_small_enabled: bool = False
    preconditions: Optional[PreconditionReport] = None
    risk_errors: list[dict] = []
    circuit_breaker: Optional[CircuitBreakerResult] = None
    config_preview: Optional[FreqtradeConfigPreview] = None


class DisableAutoResponse(BaseModel):
    state: str
    reason_codes: list[str] = []
    available_actions: list[dict] = []
    stopped_dryruns: int = 0
    command_ids: list[uuid.UUID] = []
    firewall_active: bool = False
