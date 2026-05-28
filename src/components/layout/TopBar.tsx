import { useState, useRef, useEffect } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { User, LogOut, ChevronDown, Search, Cpu, HardDrive, Wifi } from 'lucide-react'
import { useQuery } from '@tanstack/react-query'
import { apiGet } from '@/api/client'
import type { SystemMetrics } from '@/types'
import { useSystemStatus } from '@/hooks/use-dashboard'
import { useAuthStore } from '@/stores/auth-store'
import { useAppStore } from '@/stores/app-store'
import { SearchModal } from '@/components/search/SearchModal'
import { NotificationCenter } from '@/components/notifications/NotificationCenter'
import { cn } from '@/lib/utils'

const breadcrumbMap: Record<string, string> = {
  '/dashboard': '总览',
  '/strategies': '策略管理',
  '/backtest': '回测中心',
  '/trades': '交易记录',
  '/lab': 'RAG 实验室',
  '/settings': '系统设置',
  '/profile': '个人中心',
}

function TerminalClock() {
  const [time, setTime] = useState(new Date())
  useEffect(() => { const id = setInterval(() => setTime(new Date()), 1000); return () => clearInterval(id) }, [])
  const h = String(time.getHours()).padStart(2, '0')
  const m = String(time.getMinutes()).padStart(2, '0')
  const s = String(time.getSeconds()).padStart(2, '0')
  return (
    <span className="font-mono text-[11px] tracking-wider" style={{ color: 'rgba(140,255,184,0.58)' }}>
      {h}<span style={{ opacity: 0.4 }}>:</span>{m}<span style={{ opacity: 0.4 }}>:</span>{s}
    </span>
  )
}

function SystemMetricsBar() {
  const { data: metrics } = useQuery({
    queryKey: ['system', 'metrics'],
    queryFn: () => apiGet<SystemMetrics>('/api/system/metrics', () => ({
      cpu_percent: Math.floor(Math.random() * 30 + 10),
      memory_percent: Math.floor(Math.random() * 20 + 35),
      network_latency_ms: Math.floor(Math.random() * 20 + 5),
      uptime: '3d 12h', active_strategies: 3, open_positions: 2,
    })),
    refetchInterval: 10_000,
  })
  return (
    <div className="hidden lg:flex items-center gap-3">
      {[
        { icon: Cpu, label: 'CPU', value: metrics ? `${metrics.cpu_percent}%` : '--' },
        { icon: HardDrive, label: 'MEM', value: metrics ? `${metrics.memory_percent}%` : '--' },
        { icon: Wifi, label: 'NET', value: metrics ? `${metrics.network_latency_ms}ms` : '--' },
      ].map(({ icon: Icon, label, value }) => (
        <div key={label} className="flex items-center gap-1.5 px-2 py-1 rounded-md" style={{ background: 'rgba(189,255,215,0.035)', border: '1px solid rgba(189,255,215,0.06)' }}>
          <Icon className="w-3 h-3" style={{ color: '#5e6a63' }} />
          <span className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>{label}</span>
          <span className="text-[10px] font-mono font-medium" style={{ color: 'rgba(140,255,184,0.62)' }}>{value}</span>
        </div>
      ))}
    </div>
  )
}

export function TopBar({ titlebarHeight = 52 }: { titlebarHeight?: number }) {
  const { data: status } = useSystemStatus()
  const isConnected = status?.api_status === 'connected'
  const { user, logout } = useAuthStore()
  const { sidebarCollapsed, sidebarPinned } = useAppStore()
  const [showUserMenu, setShowUserMenu] = useState(false)
  const [showSearch, setShowSearch] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()
  const location = useLocation()

  const sidebarWidth = (!sidebarCollapsed || sidebarPinned) ? 248 : 64
  const pathBase = '/' + (location.pathname.split('/')[1] || 'dashboard')
  const breadcrumb = breadcrumbMap[pathBase] ?? (location.pathname.startsWith('/strategies/') ? '策略详情' : '总览')

  useEffect(() => {
    const h = (e: MouseEvent) => { if (menuRef.current && !menuRef.current.contains(e.target as Node)) setShowUserMenu(false) }
    document.addEventListener('mousedown', h)
    return () => document.removeEventListener('mousedown', h)
  }, [])

  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') setShowUserMenu(false) }
    document.addEventListener('keydown', h)
    return () => document.removeEventListener('keydown', h)
  }, [])

  return (
    <>
    <SearchModal open={showSearch} onClose={() => setShowSearch(false)} />
    <header
      className="fixed right-0 z-40"
      style={{
        top: titlebarHeight,
        left: sidebarWidth,
        height: 48,
        background: 'linear-gradient(180deg, rgba(13,18,16,0.86) 0%, rgba(7,9,8,0.9) 100%)',
        backdropFilter: 'blur(26px) saturate(120%)',
        WebkitBackdropFilter: 'blur(26px) saturate(120%)',
        borderBottom: '1px solid rgba(189,255,215,0.08)',
        transition: 'left 0.22s cubic-bezier(0.22, 1, 0.36, 1)',
      }}
    >
      <div className="h-12 flex items-center px-6 gap-4">
        <div className="text-[11px] font-mono tracking-[0.03em] no-drag" style={{ color: '#5e6a63' }}>
          PulseDesk <span style={{ color: '#344038', margin: '0 6px' }}>/</span>
          <span style={{ color: '#c5d4cc' }}>{breadcrumb}</span>
        </div>
        <div className="flex-1" />

        <div className="flex items-center gap-3 shrink-0 ml-auto no-drag">
          <SystemMetricsBar />
          <TerminalClock />
          <div className="w-px h-4" style={{ background: 'rgba(189,255,215,0.08)' }} />

          <div className="hidden sm:flex items-center gap-1.5">
            <div
              className={cn('w-1.5 h-1.5 rounded-full led-pulse', isConnected ? 'bg-success' : 'bg-danger')}
              style={{ boxShadow: isConnected ? '0 0 8px rgba(140,255,184,0.52)' : '0 0 8px rgba(255,107,107,0.52)' }}
            />
            <span className={cn('text-[10px] font-mono font-medium tracking-wider', isConnected ? 'text-success' : 'text-danger')}>
              {isConnected ? 'ONLINE' : 'OFFLINE'}
            </span>
          </div>

          <button
            onClick={() => setShowSearch(true)}
            className="p-2 cursor-pointer transition-colors rounded-lg hover:bg-white/[0.04]"
            style={{ color: '#5e6a63' }}
            aria-label="搜索"
          >
            <Search className="w-3.5 h-3.5" />
          </button>

          <NotificationCenter />

          <div className="w-px h-4" style={{ background: 'rgba(189,255,215,0.08)' }} />

          <div ref={menuRef} className="relative">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              aria-expanded={showUserMenu}
              aria-haspopup="true"
              aria-label="用户菜单"
              className="flex items-center gap-2 px-2 py-1 cursor-pointer rounded-lg hover:bg-white/[0.04] transition-colors"
            >
              <div
                className="w-7 h-7 flex items-center justify-center text-[11px] font-bold font-mono"
                style={{
                  background: 'linear-gradient(135deg, rgba(140,255,184,0.14), rgba(125,183,255,0.07))',
                  border: '1px solid rgba(140,255,184,0.2)',
                  color: '#8cffb8',
                  borderRadius: 8,
                }}
              >
                {user?.username?.[0]?.toUpperCase() || 'Q'}
              </div>
              <ChevronDown className={cn('w-3 h-3 transition-transform', showUserMenu && 'rotate-180')} style={{ color: '#5e6a63' }} />
            </button>

            {showUserMenu && (
              <div
                role="menu"
                className="absolute right-0 top-full mt-2 w-52 py-1 z-50"
                style={{
                  background: 'rgba(15, 22, 18, 0.96)',
                  border: '1px solid rgba(189,255,215,0.12)',
                  boxShadow: '0 20px 60px rgba(0,0,0,0.52)',
                  borderRadius: 8,
                  backdropFilter: 'blur(30px)',
                }}
              >
                <div className="px-3 py-2.5 mb-1" style={{ borderBottom: '1px solid rgba(189,255,215,0.08)' }}>
                  <div className="text-[12px] font-mono font-semibold" style={{ color: '#e7f0ea' }}>{user?.username || 'QuantTrader'}</div>
                  <div className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>{user?.email || 'trader@pulsedesk.local'}</div>
                </div>
                <button
                  role="menuitem"
                  onClick={() => { navigate('/profile'); setShowUserMenu(false) }}
                  className="w-full flex items-center gap-2.5 px-3 py-2 cursor-pointer text-[12px] font-mono hover:bg-white/[0.03] transition-colors rounded-lg mx-0"
                  style={{ color: '#9aa8a0' }}
                >
                  <User className="w-3.5 h-3.5" /> 个人中心
                </button>
                <div className="my-1 mx-2 border-t" style={{ borderColor: 'rgba(189,255,215,0.08)' }} />
                <button
                  role="menuitem"
                  onClick={() => { logout(); navigate('/'); setShowUserMenu(false) }}
                  className="w-full flex items-center gap-2.5 px-3 py-2 cursor-pointer text-[12px] font-mono hover:bg-white/[0.03] transition-colors rounded-lg mx-0"
                  style={{ color: '#ff6b6b' }}
                >
                  <LogOut className="w-3.5 h-3.5" /> 退出登录
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
    </>
  )
}
