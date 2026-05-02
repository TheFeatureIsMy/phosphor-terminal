import { apiGet, apiPost, apiPut, apiDelete } from './client'
import { mockStrategies } from './mock-data'
import type { Strategy } from '@/types'

const strategies: Strategy[] = mockStrategies()
let nextId = strategies.length + 1

export async function getStrategies(): Promise<Strategy[]> {
  return apiGet('/api/strategies', () => [...strategies])
}

export async function getStrategy(id: number): Promise<Strategy> {
  return apiGet(`/api/strategies/${id}`, () => {
    const s = strategies.find(s => s.id === id)
    if (!s) throw new Error('Strategy not found')
    return { ...s }
  })
}

export async function createStrategy(data: Partial<Strategy>): Promise<Strategy> {
  return apiPost('/api/strategies', data, () => {
    const newStrategy: Strategy = {
      id: nextId++,
      user_id: 1,
      name: data.name || 'New Strategy',
      type: data.type || 'ma_cross',
      parameters: data.parameters || {},
      source: 'manual',
      market: data.market || 'crypto',
      exchange: data.exchange || 'binance',
      version: 1,
      status: 'draft',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }
    strategies.push(newStrategy)
    return { ...newStrategy }
  })
}

export async function updateStrategy(id: number, data: Partial<Strategy>): Promise<Strategy> {
  return apiPut(`/api/strategies/${id}`, data, () => {
    const idx = strategies.findIndex(s => s.id === id)
    if (idx === -1) throw new Error('Strategy not found')
    strategies[idx] = { ...strategies[idx], ...data, updated_at: new Date().toISOString() }
    return { ...strategies[idx] }
  })
}

export async function deleteStrategy(id: number): Promise<void> {
  return apiDelete(`/api/strategies/${id}`, () => {
    const idx = strategies.findIndex(s => s.id === id)
    if (idx !== -1) strategies.splice(idx, 1)
  })
}
