/**
 * Frontend constants
 */

// API
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'
export const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'

// Timeouts
export const REQUEST_TIMEOUT = 15000
export const DEBOUNCE_DELAY = 300
export const POLL_INTERVAL = 30000

// Pagination
export const DEFAULT_PAGE_SIZE = 20
export const MAX_PAGE_SIZE = 100

// UI
export const SIDEBAR_WIDTH = 240
export const SIDEBAR_COLLAPSED_WIDTH = 72
export const TOPBAR_HEIGHT = 52

// Trading
export const EXCHANGES = ['binance', 'okx', 'bybit', 'gate'] as const
export const TRADING_MODES = ['spot', 'futures', 'margin'] as const
export const MARKETS = ['crypto', 'forex', 'stocks'] as const
export const TIMEFRAMES = ['1m', '5m', '15m', '1h', '4h', '1d'] as const

// Colors
export const COLORS = {
  profit: '#00ff9d',
  loss: '#ff3b3b',
  warning: '#ff9500',
  info: '#00c2ff',
  primary: '#8b5cf6',
  secondary: '#06b6d4',
} as const

// Breakpoints
export const BREAKPOINTS = {
  sm: 640,
  md: 768,
  lg: 1024,
  xl: 1280,
} as const
