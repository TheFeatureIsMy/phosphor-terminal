import { useState, useRef, useEffect } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import {
  Activity, LayoutDashboard, GitBranch, Settings, ArrowLeftRight, BarChart3,
  Bell, User, LogOut, ChevronDown, Search, Cpu, HardDrive, Wifi
} from 'lucide-react'
import { useSystemStatus } from '@/hooks/use-dashboard'
import { useAuthStore } from '@/stores/auth-store'
import { SearchModal } from '@/components/search/SearchModal'
import { NotificationCenter } from '@/components/notifications/NotificationCenter'
import { cn } from '@/lib/utils'

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: '总览', desc: 'DATA', end: true },
  { to: '/strategies', icon: GitBranch, label: '策略', desc: 'STRATEGY', end: false },
  { to: '/trades', icon: ArrowLeftRight, label: '交易', desc: 'TRADES', end: false },
  { to: '/backtest', icon: BarChart3, label: '回测', desc: 'BACKTEST', end: false },
  { to: '/settings', icon: Settings, label: '系统', desc: 'CONFIG', end: false },
]

function TerminalClock() {
  const [time, setTime] = useState(new Date())
  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000)
    return () => clearInterval(id)
  }, [])
  const h = String(time.getHours()).padStart(2, '0')
  const m = String(time.getMinutes()).padStart(2, '0')
  const s = String(time.getSeconds()).padStart(2, '0')
  return (
    <span className="font-mono text-[11px] tracking-wider" style={{ color: 'rgba(0,255,157,0.6)' }}>
      {h}:{m}<span className="cursor-blink" style={{ animation: 'blink 1s step-end infinite' }}>:</span>{s}
    </span>
  )
}

function SystemMetrics() {
  return (
    <div className="hidden lg:flex items-center gap-4 mr-2">
      {[
        { icon: Cpu, label: 'CPU', value: '23%' },
        { icon: HardDrive, label: 'MEM', value: '41%' },
        { icon: Wifi, label: 'NET', value: '12ms' },
      ].map(({ icon: Icon, label, value }) => (
        <div key={label} className="flex items-center gap-1.5">
          <Icon className="w-3 h-3" style={{ color: 'rgba(255,255,255,0.2)' }} />
          <span className="text-[10px] font-mono tracking-wider" style={{ color: 'rgba(255,255,255,0.25)' }}>{label}</span>
          <span className="text-[10px] font-mono font-medium" style={{ color: 'rgba(0,255,157,0.5)' }}>{value}</span>
        </div>
      ))}
    </div>
  )
}

export function TopBar() {
  const { data: status } = useSystemStatus()
  const isConnected = status?.api_status === 'connected'
  const { user, logout } = useAuthStore()
  const [showUserMenu, setShowUserMenu] = useState(false)
  const [showSearch, setShowSearch] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setShowUserMenu(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowUserMenu(false)
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [])

  return (
    <>
    <SearchModal open={showSearch} onClose={() => setShowSearch(false)} />
    <header
      className="fixed top-0 left-0 right-0 z-50"
      style={{
        background: 'rgba(10, 10, 10, 0.92)',
        backdropFilter: 'blur(16px)',
        WebkitBackdropFilter: 'blur(16px)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
      }}
    >
      <div className="h-[52px] flex items-center px-5 gap-3">
        {/* === Logo === */}
        <NavLink to="/dashboard" className="flex items-center gap-2.5 cursor-pointer shrink-0" aria-label="首页">
          <div className="w-7 h-7 flex items-center justify-center"
            style={{
              background: 'rgba(0, 255, 157, 0.1)',
              border: '1px solid rgba(0, 255, 157, 0.2)',
              borderRadius: '2px',
            }}>
            <Activity className="w-3.5 h-3.5" style={{ color: '#00ff9d' }} />
          </div>
          <span className="font-mono font-bold text-[13px] tracking-wider hidden md:block" style={{ color: '#e0e0e0' }}>
            CYBERQUANT
          </span>
        </NavLink>

        {/* === Separator === */}
        <div className="w-px h-5 mx-1 hidden sm:block" style={{ background: 'rgba(255,255,255,0.06)' }} />

        {/* === Nav === */}
        <nav className="flex-1 flex items-center gap-1 px-2" role="navigation">
          {navItems.map(({ to, icon: Icon, label, desc, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) => cn(
                'group flex items-center gap-2.5 px-3 py-1.5 transition-all duration-150 cursor-pointer relative',
                isActive
                  ? 'text-[#e0e0e0]'
                  : 'text-[#555] hover:text-[#888]'
              )}
            >
              {({ isActive }) => (
                <>
                  {/* Active indicator bar */}
                  {isActive && (
                    <div className="absolute left-0 top-1/2 -translate-y-1/2 w-[2px] h-4" style={{ background: '#00ff9d', boxShadow: '0 0 8px rgba(0,255,157,0.3)' }} />
                  )}
                  <Icon className="w-3.5 h-3.5 shrink-0" style={{ color: isActive ? '#00ff9d' : undefined }} />
                  <span className="text-[12px] font-medium font-mono tracking-wide hidden sm:block">{label}</span>
                  <span className="text-[9px] font-mono tracking-widest hidden xl:block" style={{ color: isActive ? 'rgba(0,255,157,0.4)' : 'rgba(255,255,255,0.12)' }}>
                    {desc}
                  </span>
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* === Right Controls === */}
        <div className="flex items-center gap-3 shrink-0 ml-auto">
          <SystemMetrics />

          {/* Clock */}
          <div className="hidden md:block"><TerminalClock /></div>

          {/* Separator */}
          <div className="w-px h-4 hidden md:block" style={{ background: 'rgba(255,255,255,0.06)' }} />

          {/* Status LED */}
          <div className="hidden sm:flex items-center gap-1.5">
            <div className={cn('w-1.5 h-1.5 rounded-full led-pulse', isConnected ? 'bg-success' : 'bg-danger')}
              style={{ boxShadow: isConnected ? '0 0 6px rgba(0,255,157,0.6)' : '0 0 6px rgba(255,59,59,0.6)' }}
            />
            <span className={cn('text-[10px] font-mono font-medium tracking-wider', isConnected ? 'text-success' : 'text-danger')}>
              {isConnected ? 'ONLINE' : 'OFFLINE'}
            </span>
          </div>

          <button
            onClick={() => setShowSearch(true)}
            className="p-1.5 cursor-pointer transition-colors duration-150"
            style={{ color: '#555', borderRadius: '2px' }}
            aria-label="搜索"
          >
            <Search className="w-3.5 h-3.5" />
          </button>

          <NotificationCenter />

          {/* Separator */}
          <div className="w-px h-4" style={{ background: 'rgba(255,255,255,0.06)' }} />

          {/* User */}
          <div ref={menuRef} className="relative">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              aria-expanded={showUserMenu}
              aria-haspopup="true"
              aria-label="用户菜单"
              className="flex items-center gap-2 px-1.5 py-1 cursor-pointer transition-colors duration-150"
              style={{ borderRadius: '2px' }}
            >
              <div className="w-7 h-7 flex items-center justify-center text-[11px] font-bold font-mono"
                style={{
                  background: 'rgba(0,255,157,0.1)',
                  border: '1px solid rgba(0,255,157,0.2)',
                  color: '#00ff9d',
                  borderRadius: '2px',
                }}>
                {user?.username?.[0]?.toUpperCase() || 'Q'}
              </div>
              <ChevronDown className={cn('w-3 h-3 transition-transform duration-150', showUserMenu && 'rotate-180')} style={{ color: '#555' }} />
            </button>

            {showUserMenu && (
              <div
                role="menu"
                className="absolute right-0 top-full mt-2 w-52 py-1 z-50"
                style={{
                  background: '#111111',
                  border: '1px solid rgba(255,255,255,0.08)',
                  boxShadow: '0 16px 48px rgba(0,0,0,0.6)',
                  borderRadius: '2px',
                }}
              >
                <div className="px-3 py-2.5 mb-1 border-b-divider">
                  <div className="text-[12px] font-mono font-semibold text-text-primary">{user?.username || 'QuantTrader'}</div>
                  <div className="text-[10px] font-mono text-text-muted">{user?.email || 'trader@cyberquant.io'}</div>
                </div>
                <button
                  role="menuitem"
                  onClick={() => { navigate('/profile'); setShowUserMenu(false) }}
                  className="w-full flex items-center gap-2.5 px-3 py-2 cursor-pointer text-[12px] font-mono transition-colors text-text-secondary"
                >
                  <User className="w-3.5 h-3.5" /> 个人中心
                </button>
                <div className="my-1 mx-2 border-t border-border" />
                <button
                  role="menuitem"
                  onClick={() => { logout(); navigate('/'); setShowUserMenu(false) }}
                  className="w-full flex items-center gap-2.5 px-3 py-2 cursor-pointer text-[12px] font-mono transition-colors text-danger"
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
