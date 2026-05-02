import type {
  Strategy, Order, OrderSide, Position, Backtest, BacktestMetrics, EquityPoint,
  DashboardKPIs, SystemStatus, RiskEvent, CorrelationSnapshot
} from '@/types'

// --- Helpers ---
function randomBetween(min: number, max: number) {
  return min + Math.random() * (max - min)
}

function randomChoice<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]
}

function generateEquityCurve(days: number, initial = 10000): EquityPoint[] {
  const points: EquityPoint[] = []
  let value = initial
  let peak = initial
  for (let i = 0; i < days; i++) {
    const change = value * randomBetween(-0.03, 0.04)
    value = Math.max(value + change, initial * 0.5)
    peak = Math.max(peak, value)
    const date = new Date()
    date.setDate(date.getDate() - (days - i))
    points.push({
      date: date.toISOString().split('T')[0],
      value: Math.round(value * 100) / 100,
      drawdown: Math.round(((value - peak) / peak) * 10000) / 100,
    })
  }
  return points
}

// --- Mock Strategies ---
const strategyNames = [
  'RSI均值回归', 'MACD趋势跟踪', '布林带突破', '网格交易-BTC',
  'ETH/BTC配对交易', '资金费率套利', '链上鲸鱼追踪', '情绪反转策略'
]

export function mockStrategies(): Strategy[] {
  return strategyNames.map((name, i) => ({
    id: i + 1,
    user_id: 1,
    name,
    type: (['ma_cross', 'breakout', 'grid', 'mean_reversion', 'rag_generated'] as const)[i % 5],
    parameters: { period: randomChoice([14, 20, 50, 100]), threshold: randomBetween(0.01, 0.05) },
    source: i < 6 ? 'manual' : i === 6 ? 'optimized' : 'rag_generated',
    market: 'crypto',
    exchange: 'binance',
    version: Math.floor(randomBetween(1, 5)),
    status: i < 2 ? 'active' : i < 4 ? 'paused' : i < 6 ? 'backtested' : 'draft',
    sharpe_ratio: Math.round(randomBetween(0.5, 2.5) * 100) / 100,
    max_drawdown: Math.round(randomBetween(5, 25) * 100) / 100,
    created_at: new Date(Date.now() - randomBetween(1, 90) * 86400000).toISOString(),
    updated_at: new Date(Date.now() - randomBetween(0, 7) * 86400000).toISOString(),
  }))
}

// --- Mock Orders ---
const symbols = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'BNB/USDT', 'XRP/USDT']

export function mockOrders(count = 50): Order[] {
  return Array.from({ length: count }, (_, i) => {
    const side: OrderSide = Math.random() > 0.5 ? 'BUY' : 'SELL'
    const price = randomBetween(100, 70000)
    const profit = randomBetween(-500, 800)
    return {
      id: i + 1,
      strategy_id: Math.floor(randomBetween(1, 5)),
      symbol: randomChoice(symbols),
      side,
      order_type: Math.random() > 0.3 ? 'market' : 'limit',
      quantity: Math.round(randomBetween(0.001, 2) * 1000) / 1000,
      price: Math.round(price * 100) / 100,
      filled_price: Math.round(price * (1 + randomBetween(-0.005, 0.005)) * 100) / 100,
      fee: Math.round(price * 0.001 * 100) / 100,
      slippage: Math.round(randomBetween(0, price * 0.002) * 100) / 100,
      timestamp: new Date(Date.now() - randomBetween(0, 30) * 86400000).toISOString(),
      status: Math.random() > 0.05 ? 'filled' : Math.random() > 0.5 ? 'cancelled' : 'failed',
      profit: Math.round(profit * 100) / 100,
      pnl_pct: Math.round((profit / (price * 0.01)) * 100) / 100,
    } satisfies Order
  }).sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
}

// --- Mock Positions ---
export function mockPositions(): Position[] {
  return [
    { id: 1, user_id: 1, strategy_id: 1, symbol: 'BTC/USDT', side: 'long', quantity: 0.5, avg_price: 62350, unrealized_pnl: 1250, stop_loss_price: 60000, take_profit_price: 68000, status: 'open', opened_at: new Date(Date.now() - 2 * 86400000).toISOString() },
    { id: 2, user_id: 1, strategy_id: 2, symbol: 'ETH/USDT', side: 'long', quantity: 5, avg_price: 3420, unrealized_pnl: -180, stop_loss_price: 3200, take_profit_price: 3800, status: 'open', opened_at: new Date(Date.now() - 1 * 86400000).toISOString() },
    { id: 3, user_id: 1, strategy_id: 3, symbol: 'SOL/USDT', side: 'short', quantity: 20, avg_price: 178, unrealized_pnl: 340, stop_loss_price: 190, status: 'open', opened_at: new Date(Date.now() - 3 * 86400000).toISOString() },
  ]
}

// --- Mock Backtest ---
export function mockBacktestMetrics(): BacktestMetrics {
  return {
    total_return: 34.7,
    sharpe_ratio: 1.82,
    max_drawdown: 12.3,
    win_rate: 62.5,
    profit_factor: 1.95,
    total_trades: 128,
    avg_trade_duration: '4h 23m',
    best_trade: 850,
    worst_trade: -320,
  }
}

export function mockBacktest(): Backtest {
  return {
    id: 1,
    strategy_id: 1,
    config: {
      start_date: '2025-01-01',
      end_date: '2025-12-31',
      initial_capital: 10000,
      symbols: ['BTC/USDT'],
    },
    result: {
      equity_curve: generateEquityCurve(365, 10000),
      trades: mockOrders(30),
      metrics: mockBacktestMetrics(),
    },
    sharpe_ratio: 1.82,
    max_drawdown: 12.3,
    win_rate: 62.5,
    total_return: 34.7,
    passed: true,
    created_at: new Date().toISOString(),
  }
}

// --- Mock Dashboard KPIs ---
export function mockDashboardKPIs(): DashboardKPIs {
  return {
    total_pnl: 12450.80,
    pnl_change_pct: 5.2,
    sharpe_ratio: 1.82,
    max_drawdown: 12.3,
    win_rate: 62.5,
    active_strategies: 2,
    todays_trades: 8,
    open_positions: 3,
  }
}

// --- Mock System Status ---
export function mockSystemStatus(): SystemStatus {
  return {
    uptime: '3d 14h 22m',
    active_strategies: 2,
    open_positions: 3,
    pending_orders: 1,
    last_data_update: new Date(Date.now() - 30000).toISOString(),
    api_status: 'connected',
  }
}

// --- Mock Risk Events ---
export function mockRiskEvents(): RiskEvent[] {
  return [
    { id: 1, event_type: 'stop_loss', strategy_id: 1, severity: 'medium', description: 'BTC/USDT 触发止损，浮亏超过5%', action_taken: '自动平仓', created_at: new Date(Date.now() - 3600000).toISOString() },
    { id: 2, event_type: 'correlation_warning', severity: 'medium', description: 'BTC/USDT 与 ETH/USDT 相关系数 0.92，组合集中度过高', action_taken: '建议减仓', created_at: new Date(Date.now() - 7200000).toISOString() },
    { id: 3, event_type: 'api_error', severity: 'high', description: 'Binance API 请求超时，已自动重试', action_taken: '重连成功', created_at: new Date(Date.now() - 86400000).toISOString() },
  ]
}

// --- Mock Correlation ---
export function mockCorrelation(): CorrelationSnapshot[] {
  return [
    { id: 1, symbol_a: 'BTC/USDT', symbol_b: 'ETH/USDT', correlation: 0.92, window_days: 30, alert_level: 'red', created_at: new Date().toISOString() },
    { id: 2, symbol_a: 'BTC/USDT', symbol_b: 'SOL/USDT', correlation: 0.78, window_days: 30, alert_level: 'normal', created_at: new Date().toISOString() },
    { id: 3, symbol_a: 'ETH/USDT', symbol_b: 'SOL/USDT', correlation: 0.85, window_days: 30, alert_level: 'yellow', created_at: new Date().toISOString() },
    { id: 4, symbol_a: 'BTC/USDT', symbol_b: 'BNB/USDT', correlation: 0.71, window_days: 30, alert_level: 'normal', created_at: new Date().toISOString() },
  ]
}

// --- Mock Equity Curve for Dashboard ---
export function mockEquityCurve(): EquityPoint[] {
  return generateEquityCurve(90, 10000)
}
