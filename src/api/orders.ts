import { apiGet } from './client'
import { mockOrders, mockPositions } from './mock-data'
import type { Order, Position } from '@/types'

export async function getOrders(limit = 50): Promise<Order[]> {
  return apiGet(`/api/orders?limit=${limit}`, () => mockOrders(limit))
}

export async function getPositions(): Promise<Position[]> {
  return apiGet('/api/positions', () => mockPositions())
}
