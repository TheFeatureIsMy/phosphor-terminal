from datetime import datetime
from typing import Any

from pydantic import BaseModel


# --- Strategy ---
class StrategyCreate(BaseModel):
    name: str
    type: str = "ma_cross"
    parameters: dict[str, Any] = {}
    market: str = "crypto"
    exchange: str = "binance"


class StrategyUpdate(BaseModel):
    name: str | None = None
    type: str | None = None
    parameters: dict[str, Any] | None = None
    status: str | None = None
    market: str | None = None
    exchange: str | None = None


class StrategyResponse(BaseModel):
    id: int
    user_id: int = 1
    name: str
    type: str
    parameters: dict[str, Any]
    source: str
    market: str
    exchange: str
    version: int
    status: str
    sharpe_ratio: float | None
    max_drawdown: float | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Order ---
class OrderResponse(BaseModel):
    id: int
    strategy_id: int
    symbol: str
    side: str
    order_type: str
    quantity: float
    price: float | None
    filled_price: float | None
    fee: float
    slippage: float
    timestamp: datetime
    status: str
    profit: float | None
    pnl_pct: float | None


# --- Position ---
class PositionResponse(BaseModel):
    id: int
    user_id: int
    strategy_id: int | None
    symbol: str
    side: str
    quantity: float
    avg_price: float
    unrealized_pnl: float
    stop_loss_price: float | None
    take_profit_price: float | None
    status: str
    opened_at: datetime
    closed_at: datetime | None


# --- Dashboard ---
class DashboardKPIsResponse(BaseModel):
    total_pnl: float
    pnl_change_pct: float
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    active_strategies: int
    todays_trades: int
    open_positions: int


class EquityPointResponse(BaseModel):
    date: str
    value: float
    drawdown: float


# --- Backtest ---
class BacktestRequest(BaseModel):
    strategy_id: int
    start_date: str = "2025-01-01"
    end_date: str = "2025-12-31"
    initial_capital: float = 10000
    symbols: list[str] = ["BTC/USDT"]


class BacktestMetricsResponse(BaseModel):
    total_return: float
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    profit_factor: float
    total_trades: int
    avg_trade_duration: str
    best_trade: float
    worst_trade: float


class BacktestResultResponse(BaseModel):
    equity_curve: list[dict[str, Any]]
    trades: list[dict[str, Any]]
    metrics: BacktestMetricsResponse


class BacktestResponse(BaseModel):
    id: int
    strategy_id: int
    config: dict[str, Any]
    result: BacktestResultResponse
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    total_return: float
    passed: bool
    created_at: datetime


# --- System ---
class SystemStatusResponse(BaseModel):
    uptime: str
    active_strategies: int
    open_positions: int
    pending_orders: int
    last_data_update: datetime
    api_status: str


# --- Risk ---
class RiskEventResponse(BaseModel):
    id: int
    event_type: str
    strategy_id: int | None
    severity: str
    description: str | None
    action_taken: str | None
    created_at: datetime


class CorrelationResponse(BaseModel):
    id: int
    symbol_a: str
    symbol_b: str
    correlation: float
    window_days: int
    alert_level: str | None
    created_at: datetime
