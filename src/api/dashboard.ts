import { apiGet, apiPost } from './client'
import {
  mockDashboardKPIs, mockEquityCurve, mockSystemStatus,
  mockRiskEvents, mockCorrelation, mockBacktest, mockBacktestMetrics
} from './mock-data'
import type { DashboardKPIs, EquityPoint, SystemStatus, RiskEvent, CorrelationSnapshot, Backtest, BacktestMetrics } from '@/types'

export async function getDashboardKPIs(): Promise<DashboardKPIs> {
  return apiGet('/api/dashboard/kpis', mockDashboardKPIs)
}

export async function getEquityCurve(): Promise<EquityPoint[]> {
  return apiGet('/api/dashboard/equity-curve', mockEquityCurve)
}

export async function getSystemStatus(): Promise<SystemStatus> {
  return apiGet('/api/system/status', mockSystemStatus)
}

export async function getRiskEvents(): Promise<RiskEvent[]> {
  return apiGet('/api/risk/events', mockRiskEvents)
}

export async function getCorrelationMatrix(): Promise<CorrelationSnapshot[]> {
  return apiGet('/api/portfolio/correlation', mockCorrelation)
}

export async function runBacktest(strategyId: number, config: Record<string, unknown>): Promise<Backtest> {
  return apiPost('/api/backtest', { strategy_id: strategyId, ...config }, mockBacktest)
}

export async function getBacktestResult(id: number): Promise<Backtest> {
  return apiGet(`/api/backtest/${id}`, mockBacktest)
}

export async function getBacktestMetrics(): Promise<BacktestMetrics> {
  return apiGet('/api/backtest/metrics', mockBacktestMetrics)
}
