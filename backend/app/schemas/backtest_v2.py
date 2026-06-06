"""Backtest v2.5 schemas — Command Bus driven."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class StartBacktestRequest(BaseModel):
    dsl: dict[str, Any] = Field(..., description="Complete StrategyRuleDSL RulePackage")
    timerange: str = Field(..., pattern=r"^\d{8}-\d{8}$", description="YYYYMMDD-YYYYMMDD")
    symbols: list[str] = Field(default=["BTC/USDT"], min_length=1)
    initial_capital: float = Field(default=10000, gt=0)
    stake_amount: float = Field(default=100, gt=0)
    max_open_trades: int = Field(default=5, ge=1)
    exchange: str = Field(default="binance")
    fee: Optional[float] = Field(default=None, ge=0, le=0.1)
    strategy_id: int = Field(default=0)
    strategy_version_id: Optional[str] = None


class StartBacktestResponse(BaseModel):
    command_id: uuid.UUID
    status: str
    message: str
    idempotency_key: str


class BacktestRunMetrics(BaseModel):
    total_return: float = 0
    sharpe_ratio: float = 0
    max_drawdown: float = 0
    win_rate: float = 0
    profit_factor: float = 0
    total_trades: int = 0
    avg_trade_duration: str = ""
    best_trade: float = 0
    worst_trade: float = 0


class BacktestRunResponse(BaseModel):
    id: int
    strategy_id: int
    strategy_version_id: Optional[str] = None
    command_id: Optional[str] = None
    dsl_hash: Optional[str] = None
    status: str
    start_date: str
    end_date: str
    initial_capital: float
    symbols: list[str] = []
    config: dict[str, Any] = {}
    result: dict[str, Any] = {}
    sharpe_ratio: float = 0
    max_drawdown: float = 0
    win_rate: float = 0
    total_return: float = 0
    profit_factor: float = 0
    total_trades: int = 0
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class BacktestStatusResponse(BaseModel):
    command_id: uuid.UUID
    command_status: str
    backtest_run: Optional[BacktestRunResponse] = None
    error_code: Optional[str] = None
    error_message: Optional[str] = None
