// Domain types matching PRD database schema

export interface User {
  id: number
  name: string
  telegram_id?: string
  email?: string
  role: 'trader' | 'admin'
  created_at: string
  updated_at: string
}

export interface DataSourceStatus {
  source: 'freqtrade' | 'freqtrade_db' | 'simulated' | 'unavailable' | string
  simulated: boolean
  available: boolean
  detail?: string | null
}

export type StrategyType = 'ma_cross' | 'breakout' | 'grid' | 'mean_reversion' | 'rag_generated'
export type StrategySource = 'manual' | 'rag_generated' | 'optimized'
export type StrategyStatus = 'draft' | 'backtested' | 'active' | 'paused' | 'retired'

export interface Strategy {
  id: number
  user_id: number
  name: string
  type: StrategyType
  parameters: Record<string, unknown>
  source: StrategySource
  market: string
  exchange: string
  version: number
  status: StrategyStatus
  sharpe_ratio?: number
  max_drawdown?: number
  freqtrade_strategy_id?: string
  created_at: string
  updated_at: string
}

export interface StrategyVersion {
  id: number
  strategy_id: number
  version: number
  parameters: Record<string, unknown>
  backtest_result?: Record<string, unknown>
  change_reason?: string
  created_at: string
}

export type OrderSide = 'BUY' | 'SELL'
export type OrderType = 'market' | 'limit'
export type OrderStatus = 'pending' | 'filled' | 'cancelled' | 'failed'

export interface Order {
  id: number
  strategy_id: number
  symbol: string
  side: OrderSide
  order_type: OrderType
  quantity: number
  price?: number
  filled_price?: number
  fee: number
  slippage: number
  timestamp: string
  status: OrderStatus
  profit?: number
  pnl_pct?: number
  data_source?: DataSourceStatus
}

export interface Position {
  id: number
  user_id: number
  strategy_id?: number
  symbol: string
  side: 'long' | 'short'
  quantity: number
  avg_price: number
  unrealized_pnl: number
  stop_loss_price?: number
  take_profit_price?: number
  status: 'open' | 'closed'
  opened_at: string
  closed_at?: string
  data_source?: DataSourceStatus
}

export interface AttributionReport {
  id: number
  order_id: number
  strategy_id: number
  feature_contributions: Record<string, number>
  top_loss_factors: string[]
  market_context: Record<string, unknown>
  summary: string
  created_at: string
}

export interface SlippageAttribution {
  id: number
  order_id: number
  signal_price: number
  filled_price: number
  execution_slippage: number
  spread_cost: number
  market_impact: number
  latency_cost: number
  slippage_pct: number
  diagnosis: string
  created_at: string
}

export interface CorrelationSnapshot {
  id: number
  symbol_a: string
  symbol_b: string
  correlation: number
  window_days: number
  alert_level?: 'normal' | 'yellow' | 'red'
  created_at: string
}

export interface PortfolioStressTest {
  id: number
  user_id: number
  scenario: string
  portfolio_var_95: number
  portfolio_cvar: number
  max_potential_drawdown: number
  concentration_risk: Record<string, unknown>
  recommendations: string
  created_at: string
}

export interface Backtest {
  id: number
  strategy_id: number
  config: {
    start_date: string
    end_date: string
    initial_capital: number
    symbols: string[]
  }
  result: {
    equity_curve: EquityPoint[]
    trades: Order[]
    metrics: BacktestMetrics
  }
  sharpe_ratio: number
  max_drawdown: number
  win_rate: number
  total_return: number
  passed: boolean
  created_at: string
  data_source?: DataSourceStatus
}

export interface BacktestMetrics {
  total_return: number
  sharpe_ratio: number
  max_drawdown: number
  win_rate: number
  profit_factor: number
  total_trades: number
  avg_trade_duration: string
  best_trade: number
  worst_trade: number
}

export interface EquityPoint {
  date: string
  value: number
  drawdown: number
  data_source?: DataSourceStatus
}

export interface SentimentData {
  id: number
  symbol: string
  source: 'twitter' | 'reddit' | 'news'
  score: number
  raw_text?: string
  model: string
  timestamp: string
}

export interface RiskEvent {
  id: number
  event_type: 'stop_loss' | 'circuit_breaker' | 'api_error' | 'data_anomaly' | 'correlation_warning'
  strategy_id?: number
  severity: 'low' | 'medium' | 'high' | 'critical'
  description?: string
  action_taken?: string
  created_at: string
}

export interface SystemStatus {
  uptime: string
  active_strategies: number
  open_positions: number
  pending_orders: number
  last_data_update: string
  api_status: 'connected' | 'disconnected' | 'error'
  data_source?: DataSourceStatus
}

// Dashboard KPI types
export interface DashboardKPIs {
  total_pnl: number
  pnl_change_pct: number
  sharpe_ratio: number
  max_drawdown: number
  win_rate: number
  active_strategies: number
  todays_trades: number
  open_positions: number
  data_source?: DataSourceStatus
}

// Constants
export const EXCHANGES = ['binance', 'okx', 'bybit', 'gate'] as const
export type Exchange = typeof EXCHANGES[number]

export const TRADING_MODES = ['spot', 'futures', 'margin'] as const
export type TradingMode = typeof TRADING_MODES[number]

export const MARKETS = ['crypto', 'forex', 'stocks'] as const
export type Market = typeof MARKETS[number]

export const TIMEFRAMES = ['1m', '5m', '15m', '1h', '4h', '1d'] as const
export type Timeframe = typeof TIMEFRAMES[number]

export interface SystemMetrics {
  cpu_percent: number
  memory_percent: number
  network_latency_ms: number
  uptime: string
  active_strategies: number
  open_positions: number
}
