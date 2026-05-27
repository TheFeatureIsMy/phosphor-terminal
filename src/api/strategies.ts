import { apiGet, apiPost, apiPut, apiDelete } from './client'
import { mockStrategies } from './mock-data'
import type { Strategy } from '@/types'

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'

const strategies: Strategy[] = mockStrategies()
let nextId = strategies.length + 1

interface PaginatedStrategies {
  items: Strategy[]
  total: number
  page: number
  page_size: number
  pages: number
}

export async function getStrategies(): Promise<Strategy[]> {
  if (USE_MOCK) {
    return [...strategies]
  }
  const res = await apiGet<PaginatedStrategies>('/api/strategies', () => ({ items: [...strategies], total: strategies.length, page: 1, page_size: 20, pages: 1 }))
  return res.items
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
