export const INDICATORS = [
  { value: 'rsi', label: 'RSI' },
  { value: 'ema', label: 'EMA' },
  { value: 'sma', label: 'SMA' },
  { value: 'macd', label: 'MACD' },
  { value: 'macd_signal', label: 'MACD Signal' },
  { value: 'bb_upper', label: 'BB Upper' },
  { value: 'bb_lower', label: 'BB Lower' },
  { value: 'atr', label: 'ATR' },
  { value: 'volume', label: 'Volume' },
  { value: 'volume_sma', label: 'Volume SMA' },
  { value: 'close', label: 'Close' },
  { value: 'open', label: 'Open' },
  { value: 'high', label: 'High' },
  { value: 'low', label: 'Low' },
] as const

export const OPERATORS = [
  { value: '>', label: '>' },
  { value: '>=', label: '>=' },
  { value: '<', label: '<' },
  { value: '<=', label: '<=' },
  { value: '==', label: '==' },
  { value: '!=', label: '!=' },
  { value: 'crosses_above', label: 'Crosses Above' },
  { value: 'crosses_below', label: 'Crosses Below' },
  { value: 'between', label: 'Between' },
  { value: 'not_between', label: 'Not Between' },
] as const

export const SCALAR_OPERATORS = ['>', '>=', '<', '<=', '==', '!=']
export const RANGE_OPERATORS = ['between', 'not_between']
export const CROSS_OPERATORS = ['crosses_above', 'crosses_below']

export const TIMEFRAMES = [
  '1m', '3m', '5m', '15m', '30m',
  '1h', '2h', '4h', '6h', '8h', '12h',
  '1d', '3d', '1w', '1M',
] as const

export const FILTER_TYPES = [
  { value: 'volume_filter', label: '成交量过滤' },
  { value: 'volatility_filter', label: '波动率过滤' },
  { value: 'manipulation_score_filter', label: '操控评分过滤' },
  { value: 'cooldown_filter', label: '冷却过滤' },
  { value: 'portfolio_exposure_filter', label: '组合敞口过滤' },
  { value: 'signal_confirmation', label: '信号确认' },
] as const

export const INDICATORS_REQUIRING_PERIOD = new Set([
  'rsi', 'ema', 'sma', 'macd', 'macd_signal',
  'bb_upper', 'bb_lower', 'atr', 'volume_sma',
])
