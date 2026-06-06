"""Dry-run v2.5 schemas — Command Bus driven."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class StartDryRunRequest(BaseModel):
    dsl: dict[str, Any] = Field(..., description="Complete StrategyRuleDSL RulePackage")
    symbols: list[str] = Field(default=["BTC/USDT"], min_length=1)
    stake_amount: float = Field(default=100, gt=0)
    max_open_trades: int = Field(default=5, ge=1)
    initial_wallet: float = Field(default=10000, gt=0)
    exchange: str = Field(default="binance")
    api_port: int = Field(default=8080, ge=1024, le=65535)
    strategy_id: int = Field(default=0)
    strategy_version_id: Optional[str] = None


class StartDryRunResponse(BaseModel):
    command_id: uuid.UUID
    status: str
    message: str
    idempotency_key: str


class StopDryRunRequest(BaseModel):
    reason: str = Field(default="user_requested")


class StopDryRunResponse(BaseModel):
    command_id: uuid.UUID
    status: str
    message: str


class DryRunRunResponse(BaseModel):
    id: int
    strategy_id: int
    strategy_version_id: Optional[str] = None
    command_id: Optional[str] = None
    dsl_hash: Optional[str] = None
    status: str
    pid: Optional[int] = None
    api_port: Optional[int] = None
    api_url: Optional[str] = None
    symbols: list[str] = []
    stake_amount: float = 100
    max_open_trades: int = 5
    initial_wallet: float = 10000
    exchange: str = "binance"
    total_trades: int = 0
    open_trades: int = 0
    total_profit: float = 0
    last_synced_at: Optional[datetime] = None
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    stopped_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class DryRunStatusResponse(BaseModel):
    command_id: uuid.UUID
    command_status: str
    dryrun_run: Optional[DryRunRunResponse] = None
    error_code: Optional[str] = None
    error_message: Optional[str] = None


class DryRunSyncResponse(BaseModel):
    dryrun_run_id: int
    new_events: int
    open_trades: int
    closed_trades: int
    success: bool
    errors: list[str] = []
