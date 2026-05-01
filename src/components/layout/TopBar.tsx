import { Bell, Wifi, WifiOff } from 'lucide-react'
import { useSystemStatus } from '@/hooks/use-dashboard'

export function TopBar() {
  const { data: status } = useSystemStatus()

  return (
    <header className="h-16 bg-surface border-b border-border flex items-center justify-between px-6">
      <div className="flex items-center gap-4">
        <h1 className="text-sm text-text-muted">
          {new Date().toLocaleDateString('zh-CN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
        </h1>
      </div>

      <div className="flex items-center gap-4">
        {/* System Status */}
        <div className="flex items-center gap-2 text-sm">
          {status?.api_status === 'connected' ? (
            <Wifi className="w-4 h-4 text-success" />
          ) : (
            <WifiOff className="w-4 h-4 text-danger" />
          )}
          <span className="text-text-secondary">
            {status?.api_status === 'connected' ? '已连接' : '断开'}
          </span>
        </div>

        {/* Uptime */}
        <span className="text-xs text-text-muted font-mono">
          Uptime: {status?.uptime || '--'}
        </span>

        {/* Notifications */}
        <button className="relative p-2 text-text-secondary hover:text-text-primary transition-colors">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-danger rounded-full" />
        </button>
      </div>
    </header>
  )
}
