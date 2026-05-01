import { useQuery } from '@tanstack/react-query'
import * as dashboardApi from '@/api/dashboard'
import * as ordersApi from '@/api/orders'

export function useDashboardKPIs() {
  return useQuery({
    queryKey: ['dashboard', 'kpis'],
    queryFn: dashboardApi.getDashboardKPIs,
    refetchInterval: 30000,
  })
}

export function useEquityCurve() {
  return useQuery({
    queryKey: ['dashboard', 'equity-curve'],
    queryFn: dashboardApi.getEquityCurve,
  })
}

export function useSystemStatus() {
  return useQuery({
    queryKey: ['system', 'status'],
    queryFn: dashboardApi.getSystemStatus,
    refetchInterval: 10000,
  })
}

export function useRiskEvents() {
  return useQuery({
    queryKey: ['risk', 'events'],
    queryFn: dashboardApi.getRiskEvents,
  })
}

export function useOrders(limit?: number) {
  return useQuery({
    queryKey: ['orders', limit],
    queryFn: () => ordersApi.getOrders(limit),
  })
}

export function usePositions() {
  return useQuery({
    queryKey: ['positions'],
    queryFn: ordersApi.getPositions,
    refetchInterval: 15000,
  })
}

export function useCorrelationMatrix() {
  return useQuery({
    queryKey: ['portfolio', 'correlation'],
    queryFn: dashboardApi.getCorrelationMatrix,
  })
}
