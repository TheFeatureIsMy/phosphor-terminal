from datetime import datetime
from enum import Enum
from typing import List,  Dict,  Optional,  Any
from pydantic import BaseModel, Field
class DataSourceStatus(BaseModel):
    source: str
    simulated: bool = False
    available: bool = True
    detail: Optional[str] = None
# --- Enums ---
class StrategyType(str, Enum):
    ma_cross = "ma_cross"
    breakout = "breakout"
    grid = "grid"
    mean_reversion = "mean_reversion"
    rag_generated = "rag_generated"
class StrategyStatus(str, Enum):
    draft = "draft"
    backtested = "backtested"
    active = "active"
    paused = "paused"
    retired = "retired"
class StrategySource(str, Enum):
    manual = "manual"
    rag_generated = "rag_generated"
    optimized = "optimized"
# --- Strategy ---
class StrategyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    type: StrategyType = StrategyType.ma_cross
    parameters: Dict[str, Any] = {}
    market: str = "crypto"
    exchange: str = "binance"
class StrategyUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    type: Optional[StrategyType] = None
    parameters: Optional[Dict[str, Any]] = None
    status: Optional[StrategyStatus] = None
    market: Optional[str] = None
    exchange: Optional[str] = None
class StrategyResponse(BaseModel):
    id: int
    user_id: int = 1
    name: str
    type: StrategyType
    parameters: Dict[str, Any]
    source: StrategySource
    market: str
    exchange: str
    version: int
    status: StrategyStatus
    sharpe_ratio: Optional[float]
    max_drawdown: Optional[float]
    freqtrade_strategy_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}
class PaginatedResponse(BaseModel):
    items: list[Any]
    total: int
    page: int
    page_size: int
    pages: int
# --- Order ---
class OrderResponse(BaseModel):
    id: int
    strategy_id: int
    symbol: str
    side: str
    order_type: str
    quantity: float
    price: Optional[float]
    filled_price: Optional[float]
    fee: float
    slippage: float
    timestamp: datetime
    status: str
    profit: Optional[float]
    pnl_pct: Optional[float]
    data_source: Optional[DataSourceStatus] = None
# --- Position ---
class PositionResponse(BaseModel):
    id: int
    user_id: int
    strategy_id: Optional[int]
    symbol: str
    side: str
    quantity: float
    avg_price: float
    unrealized_pnl: float
    stop_loss_price: Optional[float]
    take_profit_price: Optional[float]
    status: str
    opened_at: datetime
    closed_at: Optional[datetime]
    data_source: Optional[DataSourceStatus] = None
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
    data_source: Optional[DataSourceStatus] = None
class EquityPointResponse(BaseModel):
    date: str
    value: float
    drawdown: float
    data_source: Optional[DataSourceStatus] = None
# --- Backtest ---
class BacktestRequest(BaseModel):
    strategy_id: int
    start_date: str = "2025-01-01"
    end_date: str = "2025-12-31"
    initial_capital: float = 10000
    symbols: List[str] = ["BTC/USDT"]
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
    equity_curve: list[Dict[str, Any]]
    trades: list[Dict[str, Any]]
    metrics: BacktestMetricsResponse
class BacktestResponse(BaseModel):
    id: int
    strategy_id: int
    config: Dict[str, Any]
    result: BacktestResultResponse
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    total_return: float
    passed: bool
    created_at: datetime
    data_source: DataSourceStatus
# --- System ---
class SystemStatusResponse(BaseModel):
    uptime: str
    active_strategies: int
    open_positions: int
    pending_orders: int
    last_data_update: datetime
    api_status: str
    data_source: DataSourceStatus
# --- Risk ---
class RiskEventResponse(BaseModel):
    id: int
    event_type: str
    strategy_id: Optional[int]
    severity: str
    description: Optional[str]
    action_taken: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class RiskRuleEvaluationRequest(BaseModel):
    strategy_id: Optional[int] = None
    market: str = "crypto"
    symbol: Optional[str] = None
    position_pnl_pct: Optional[float] = None
    take_profit_pct: Optional[float] = None
    drawdown_pct: Optional[float] = None
    max_drawdown_pct: float = 10
    correlation_pairs: List[Dict[str, Any]] = []
    api_error: Optional[str] = None
    dry_run: bool = False


class RiskRuleEvaluationResponse(BaseModel):
    status: str
    created_events: List[RiskEventResponse]
    dry_run: bool = False
class CorrelationResponse(BaseModel):
    id: int
    symbol_a: str
    symbol_b: str
    correlation: float
    window_days: int
    alert_level: Optional[str]
    created_at: datetime


class AttributionReportCreate(BaseModel):
    trade_id: int
    strategy_id: Optional[int] = None
    feature_contributions: Dict[str, float] = {}
    top_loss_factors: List[str] = []
    market_context: Dict[str, Any] = {}
    summary: Optional[str] = None


class AttributionReportResponse(AttributionReportCreate):
    id: int
    created_at: datetime
    model_config = {"from_attributes": True}


class SlippageAttributionCreate(BaseModel):
    trade_id: int
    signal_price: float
    filled_price: float
    spread_cost: float = 0
    market_impact: float = 0
    latency_cost: float = 0


class SlippageAttributionResponse(BaseModel):
    id: int
    trade_id: int
    signal_price: float
    filled_price: float
    execution_slippage: float
    spread_cost: float
    market_impact: float
    latency_cost: float
    slippage_pct: float
    diagnosis: Optional[str]
    created_at: datetime
    model_config = {"from_attributes": True}


class SentimentDataCreate(BaseModel):
    symbol: str
    market: str = "crypto"
    source: str
    score: float
    raw_text: Optional[str] = None
    model: str = "finbert"


class SentimentDataResponse(SentimentDataCreate):
    id: int
    timestamp: datetime
    model_config = {"from_attributes": True}


class PortfolioStressTestCreate(BaseModel):
    user_id: int = 1
    market: str = "crypto"
    scenario: str
    portfolio_var_95: float
    portfolio_cvar: float
    max_potential_drawdown: float
    concentration_risk: Dict[str, Any] = {}
    recommendations: Optional[str] = None


class PortfolioStressTestResponse(PortfolioStressTestCreate):
    id: int
    created_at: datetime
    model_config = {"from_attributes": True}
