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

export async function register(username: string, email: string, password: string): Promise<UserResponse> {
  const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/auth/register`, {
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
  const formData = new URLSearchParams()
  formData.append('username', username)
  formData.append('password', password)

  const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/auth/login`, {
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
  const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: refreshTok }),
  })
  if (!res.ok) throw new Error('Token refresh failed')
  return res.json()
}

export async function getMe(token: string): Promise<UserResponse> {
  const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  if (!res.ok) throw new Error('Failed to get user')
  return res.json()
}

export async function getSettings(token: string): Promise<UserSettingsResponse> {
  const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/auth/settings`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  if (!res.ok) throw new Error('Failed to get settings')
  return res.json()
}

export async function updateSettings(token: string, settings: Partial<UserSettingsResponse>): Promise<UserSettingsResponse> {
  const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/auth/settings`, {
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
