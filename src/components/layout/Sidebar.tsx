import { NavLink } from 'react-router-dom'
import { motion } from 'framer-motion'
import {
  LayoutDashboard, GitBranch, Settings, Activity,
  ChevronLeft, ChevronRight, Search,
  BarChart3, ArrowLeftRight, User, Sparkles
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { useAppStore } from '@/stores/app-store'
import { useSystemStatus } from '@/hooks/use-dashboard'

const navSections = [
  {
    label: '交易',
    items: [
      { to: '/dashboard', icon: LayoutDashboard, label: '总览' },
      { to: '/strategies', icon: GitBranch, label: '策略管理' },
      { to: '/trades', icon: ArrowLeftRight, label: '交易记录' },
      { to: '/backtest', icon: BarChart3, label: '回测分析' },
      { to: '/lab', icon: Sparkles, label: '策略实验室' },
    ],
  },
  {
    label: '系统',
    items: [
      { to: '/settings', icon: Settings, label: '系统设置' },
      { to: '/profile', icon: User, label: '个人中心' },
    ],
  },
]

export function Sidebar() {
  const { sidebarCollapsed, toggleSidebar } = useAppStore()
  const { data: status } = useSystemStatus()

  return (
    <motion.aside
      aria-label="主导航"
      animate={{ width: sidebarCollapsed ? 72 : 240 }}
      transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
      className="fixed left-0 top-0 h-dvh flex flex-col z-50"
      style={{
        background: 'rgba(255, 255, 255, 0.03)',
        backdropFilter: 'blur(40px)',
        WebkitBackdropFilter: 'blur(40px)',
        borderRight: '1px solid rgba(255, 255, 255, 0.06)',
      }}
    >
      {/* Logo */}
      <div className="h-14 flex items-center px-4 shrink-0" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        <NavLink to="/dashboard" className="flex items-center gap-2.5 cursor-pointer" aria-label="首页">
          <div className="w-8 h-8 flex items-center justify-center shrink-0"
            style={{
              background: 'linear-gradient(135deg, rgba(139,92,246,0.25), rgba(6,182,212,0.25))',
              borderRadius: '10px',
            }}>
            <Activity className="w-4 h-4 text-primary" />
          </div>
          {!sidebarCollapsed && (
            <span className="font-bold text-[14px] tracking-tight" style={{ fontFamily: 'Sora, sans-serif' }}>
              CyberQuant
            </span>
          )}
        </NavLink>
      </div>

      {/* Search */}
      {!sidebarCollapsed && (
        <div className="px-3 pt-3 pb-1 shrink-0">
          <button
            className="w-full flex items-center gap-2.5 px-3 py-2 text-[13px] text-text-muted hover:text-text-secondary transition-colors cursor-pointer"
            style={{
              background: 'rgba(255,255,255,0.04)',
              borderRadius: '10px',
              border: '1px solid rgba(255,255,255,0.06)',
            }}
          >
            <Search className="w-3.5 h-3.5 shrink-0" />
            <span className="flex-1 text-left">搜索...</span>
            <kbd className="text-[10px] px-1.5 py-0.5 rounded bg-white/[0.06] text-text-muted">⌘K</kbd>
          </button>
        </div>
      )}

      {/* Navigation Sections */}
      <nav className="flex-1 overflow-y-auto px-3 py-2 space-y-4" role="navigation">
        {navSections.map((section) => (
          <div key={section.label}>
            {!sidebarCollapsed && (
              <div className="px-3 mb-1.5">
                <span className="text-[10px] font-semibold tracking-wider uppercase text-text-muted">
                  {section.label}
                </span>
              </div>
            )}
            <div className="space-y-0.5">
              {section.items.map(({ to, icon: Icon, label }) => (
                <NavLink
                  key={to + label}
                  to={to}
                  end={to === '/dashboard'}
                  className={({ isActive }) => cn(
                    'flex items-center gap-2.5 transition-all duration-150 cursor-pointer',
                    sidebarCollapsed ? 'justify-center px-0 py-2' : 'px-3 py-2',
                    isActive
                      ? 'text-white font-medium'
                      : 'text-text-muted hover:text-text-secondary hover:bg-white/[0.04]'
                  )}
                  style={({ isActive }) => isActive ? {
                    background: 'rgba(139, 92, 246, 0.12)',
                    borderRadius: '10px',
                    boxShadow: 'inset 0 0 0 1px rgba(139, 92, 246, 0.2)',
                  } : {
                    borderRadius: '10px',
                  }}
                >
                  <Icon className="w-[18px] h-[18px] shrink-0" aria-hidden="true" />
                  {!sidebarCollapsed && <span className="text-[13px]">{label}</span>}
                </NavLink>
              ))}
            </div>
          </div>
        ))}
      </nav>

      {/* Bottom: Status + User */}
      <div className="shrink-0 px-3 pb-3 space-y-2" style={{ borderTop: '1px solid rgba(255,255,255,0.06)', paddingTop: '12px' }}>
        {/* System Status */}
        {!sidebarCollapsed && (
          <div className="flex items-center gap-2.5 px-3 py-2" style={{
            background: status?.api_status === 'connected' ? 'rgba(16,185,129,0.06)' : 'rgba(239,68,68,0.06)',
            borderRadius: '10px',
            border: `1px solid ${status?.api_status === 'connected' ? 'rgba(16,185,129,0.12)' : 'rgba(239,68,68,0.12)'}`,
          }}>
            <div className={cn('w-2 h-2 rounded-full shrink-0', status?.api_status === 'connected' ? 'bg-success' : 'bg-danger')}
              style={{ boxShadow: status?.api_status === 'connected' ? '0 0 6px rgba(16,185,129,0.5)' : '0 0 6px rgba(239,68,68,0.5)' }}
            />
            <div className="min-w-0">
              <div className="text-[12px] font-medium text-success leading-tight">
                {status?.api_status === 'connected' ? '系统正常' : '连接断开'}
              </div>
              <div className="text-[10px] text-text-muted truncate">{status?.uptime || '--'}</div>
            </div>
          </div>
        )}

        {/* User */}
        {!sidebarCollapsed && (
          <NavLink
            to="/profile"
            className="flex items-center gap-2.5 px-3 py-2 cursor-pointer hover:bg-white/[0.04] transition-colors"
            style={{ borderRadius: '10px' }}
          >
            <div className="w-7 h-7 flex items-center justify-center text-[11px] font-bold shrink-0"
              style={{ background: 'linear-gradient(135deg, #8b5cf6, #06b6d4)', color: 'white', borderRadius: '8px' }}>
              Q
            </div>
            <div className="min-w-0">
              <div className="text-[13px] font-medium text-text-primary truncate">QuantTrader</div>
              <div className="text-[10px] text-text-muted truncate">trader@cyberquant.io</div>
            </div>
          </NavLink>
        )}

        {/* Collapse Toggle */}
        <button
          onClick={toggleSidebar}
          aria-label={sidebarCollapsed ? '展开侧边栏' : '收起侧边栏'}
          className="w-full flex items-center justify-center py-1.5 cursor-pointer text-text-muted hover:text-text-secondary transition-colors"
          style={{ borderRadius: '8px' }}
        >
          {sidebarCollapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </button>
      </div>
    </motion.aside>
  )
}
