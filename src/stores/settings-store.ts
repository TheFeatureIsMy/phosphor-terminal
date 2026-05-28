import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface ExchangeConfig {
  exchange: string
  tradingMode: string
  apiKey: string
  apiSecret: string
  futuresEnabled: boolean
  dryRun: boolean
}

interface RiskConfig {
  maxSingleLossPct: number
  maxDrawdownPct: number
  dailyDrawdownPct: number
  maxPositionPct: number
  correlatedGroupLimitPct: number
  correlationThreshold: number
  autoPauseOnRisk: boolean
}

interface NotificationConfig {
  botToken: string
  chatId: string
  tradeNotifications: boolean
  riskNotifications: boolean
  dailyReport: boolean
  correlationAlerts: boolean
}

interface SettingsState {
  exchange: ExchangeConfig
  risk: RiskConfig
  notifications: NotificationConfig
  updateExchange: (data: Partial<ExchangeConfig>) => void
  updateRisk: (data: Partial<RiskConfig>) => void
  updateNotifications: (data: Partial<NotificationConfig>) => void
  loadFromBackend: (settings: {
    default_exchange?: string
    default_market?: string
    risk_tolerance?: string
    notifications_enabled?: boolean
  }) => void
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      exchange: {
        exchange: 'binance',
        tradingMode: 'spot',
        apiKey: '',
        apiSecret: '',
        futuresEnabled: true,
        dryRun: false,
      },
      risk: {
        maxSingleLossPct: 2,
        maxDrawdownPct: 15,
        dailyDrawdownPct: 5,
        maxPositionPct: 30,
        correlatedGroupLimitPct: 50,
        correlationThreshold: 0.8,
        autoPauseOnRisk: true,
      },
      notifications: {
        botToken: '',
        chatId: '',
        tradeNotifications: true,
        riskNotifications: true,
        dailyReport: true,
        correlationAlerts: false,
      },
      updateExchange: (data) => set((s) => ({ exchange: { ...s.exchange, ...data } })),
      updateRisk: (data) => set((s) => ({ risk: { ...s.risk, ...data } })),
      updateNotifications: (data) => set((s) => ({ notifications: { ...s.notifications, ...data } })),
      loadFromBackend: (settings) =>
        set((s) => ({
          exchange: {
            ...s.exchange,
            exchange: settings.default_exchange || s.exchange.exchange,
          },
          notifications: {
            ...s.notifications,
            tradeNotifications: settings.notifications_enabled ?? s.notifications.tradeNotifications,
          },
        })),
    }),
    {
      name: 'pulsedesk-settings',
    }
  )
)
