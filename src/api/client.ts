const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'
const REQUEST_TIMEOUT = 15000

async function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function mockDelay() {
  await sleep(200 + Math.random() * 300)
}

class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
    this.name = 'ApiError'
  }
}

async function fetchWithTimeout(url: string, options: RequestInit = {}): Promise<Response> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT)
  try {
    const res = await fetch(url, { ...options, signal: controller.signal })
    return res
  } finally {
    clearTimeout(timeout)
  }
}

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let message = `API Error: ${res.status}`
    try {
      const body = await res.json()
      if (body.detail) message = typeof body.detail === 'string' ? body.detail : JSON.stringify(body.detail)
    } catch { /* ignore parse error */ }
    throw new ApiError(res.status, message)
  }
  return res.json()
}

export async function apiGet<T>(endpoint: string, mockFn: () => T): Promise<T> {
  if (USE_MOCK) {
    await mockDelay()
    return mockFn()
  }
  const res = await fetchWithTimeout(`${API_BASE}${endpoint}`)
  return handleResponse<T>(res)
}

export async function apiPost<T>(endpoint: string, body: unknown, mockFn: () => T): Promise<T> {
  if (USE_MOCK) {
    await mockDelay()
    return mockFn()
  }
  const res = await fetchWithTimeout(`${API_BASE}${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  return handleResponse<T>(res)
}

export async function apiPut<T>(endpoint: string, body: unknown, mockFn: () => T): Promise<T> {
  if (USE_MOCK) {
    await mockDelay()
    return mockFn()
  }
  const res = await fetchWithTimeout(`${API_BASE}${endpoint}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  return handleResponse<T>(res)
}

export async function apiDelete(endpoint: string, mockFn: () => void): Promise<void> {
  if (USE_MOCK) {
    await mockDelay()
    mockFn()
    return
  }
  const res = await fetchWithTimeout(`${API_BASE}${endpoint}`, { method: 'DELETE' })
  if (!res.ok) {
    let message = `API Error: ${res.status}`
    try {
      const body = await res.json()
      if (body.detail) message = typeof body.detail === 'string' ? body.detail : JSON.stringify(body.detail)
    } catch { /* ignore parse error */ }
    throw new ApiError(res.status, message)
  }
}
