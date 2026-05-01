const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

async function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function mockDelay() {
  await sleep(200 + Math.random() * 300)
}

export async function apiGet<T>(endpoint: string, mockFn: () => T): Promise<T> {
  if (USE_MOCK) {
    await mockDelay()
    return mockFn()
  }
  const res = await fetch(`${API_BASE}${endpoint}`)
  if (!res.ok) throw new Error(`API Error: ${res.status}`)
  return res.json()
}

export async function apiPost<T>(endpoint: string, body: unknown, mockFn: () => T): Promise<T> {
  if (USE_MOCK) {
    await mockDelay()
    return mockFn()
  }
  const res = await fetch(`${API_BASE}${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`API Error: ${res.status}`)
  return res.json()
}

export async function apiPut<T>(endpoint: string, body: unknown, mockFn: () => T): Promise<T> {
  if (USE_MOCK) {
    await mockDelay()
    return mockFn()
  }
  const res = await fetch(`${API_BASE}${endpoint}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`API Error: ${res.status}`)
  return res.json()
}

export async function apiDelete(endpoint: string, mockFn: () => void): Promise<void> {
  if (USE_MOCK) {
    await mockDelay()
    mockFn()
    return
  }
  const res = await fetch(`${API_BASE}${endpoint}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`API Error: ${res.status}`)
}
