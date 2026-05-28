const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

interface TokenResponse {
  access_token: string
  refresh_token: string
  token_type: string
}

interface UserResponse {
  id: number
  username: string
  email: string
  is_active: boolean
  avatar_url: string | null
  created_at: string
}

interface UserSettingsResponse {
  id: number
  user_id: number
  theme: string
  language: string
  notifications_enabled: boolean
  default_exchange: string
  default_market: string
  risk_tolerance: string
  created_at: string
  updated_at: string
}

// Mock data
const MOCK_USER: UserResponse = {
  id: 1,
  username: 'QuantTrader',
  email: 'trader@pulsedesk.local',
  is_active: true,
  avatar_url: null,
  created_at: '2026-01-01T00:00:00Z',
}

const MOCK_SETTINGS: UserSettingsResponse = {
  id: 1,
  user_id: 1,
  theme: 'dark',
  language: 'zh-CN',
  notifications_enabled: true,
  default_exchange: 'binance',
  default_market: 'spot',
  risk_tolerance: 'medium',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
}

const MOCK_TOKENS: TokenResponse = {
  access_token: 'mock-access-token-' + Date.now(),
  refresh_token: 'mock-refresh-token-' + Date.now(),
  token_type: 'bearer',
}

async function mockDelay() {
  await new Promise(r => setTimeout(r, 200 + Math.random() * 300))
}

export async function register(username: string, email: string, password: string): Promise<UserResponse> {
  if (USE_MOCK) {
    await mockDelay()
    return { ...MOCK_USER, username, email }
  }
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, email, password }),
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.detail || 'Registration failed')
  }
  return res.json()
}

export async function login(username: string, password: string): Promise<TokenResponse> {
  if (USE_MOCK) {
    await mockDelay()
    if (!username || !password) throw new Error('请输入用户名和密码')
    return MOCK_TOKENS
  }
  const formData = new URLSearchParams()
  formData.append('username', username)
  formData.append('password', password)

  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: formData,
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.detail || 'Login failed')
  }
  return res.json()
}

export async function refreshToken(refreshTok: string): Promise<TokenResponse> {
  if (USE_MOCK) {
    await mockDelay()
    return MOCK_TOKENS
  }
  const res = await fetch(`${API_BASE}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: refreshTok }),
  })
  if (!res.ok) throw new Error('Token refresh failed')
  return res.json()
}

export async function getMe(token: string): Promise<UserResponse> {
  if (USE_MOCK) {
    await mockDelay()
    return MOCK_USER
  }
  const res = await fetch(`${API_BASE}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  if (!res.ok) throw new Error('Failed to get user')
  return res.json()
}

export async function getSettings(token: string): Promise<UserSettingsResponse> {
  if (USE_MOCK) {
    await mockDelay()
    return MOCK_SETTINGS
  }
  const res = await fetch(`${API_BASE}/auth/settings`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  if (!res.ok) throw new Error('Failed to get settings')
  return res.json()
}

export async function updateSettings(token: string, settings: Partial<UserSettingsResponse>): Promise<UserSettingsResponse> {
  if (USE_MOCK) {
    await mockDelay()
    return { ...MOCK_SETTINGS, ...settings }
  }
  const res = await fetch(`${API_BASE}/auth/settings`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(settings),
  })
  if (!res.ok) throw new Error('Failed to update settings')
  return res.json()
}
