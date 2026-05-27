import { useAuthStore } from '@/stores/auth-store'
import { getSettings, updateSettings } from '@/api/auth'

interface BackendSettings {
  theme: string
  language: string
  notifications_enabled: boolean
  default_exchange: string
  default_market: string
  risk_tolerance: string
}

export function useSettingsSync() {
  const { isAuthenticated, accessToken } = useAuthStore()

  const loadSettings = async (): Promise<BackendSettings | null> => {
    if (!isAuthenticated || !accessToken) return null
    try {
      return await getSettings(accessToken)
    } catch {
      return null
    }
  }

  const saveSettings = async (settings: Partial<BackendSettings>): Promise<boolean> => {
    if (!isAuthenticated || !accessToken) return false
    try {
      await updateSettings(accessToken, settings)
      return true
    } catch {
      return false
    }
  }

  return { loadSettings, saveSettings }
}
