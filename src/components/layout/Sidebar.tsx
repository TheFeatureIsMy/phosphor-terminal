import { useRef, useCallback } from 'react'
import { NavLink } from 'react-router-dom'
import {
  BarChart3, FlaskConical, GitBranch, LayoutDashboard,
  Settings, User, ArrowLeftRight, Pin
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { useSystemStatus } from '@/hooks/use-dashboard'
import { useAppStore } from '@/stores/app-store'
import { PulseDeskLogo } from '@/components/brand/PulseDeskLogo'

const navSections = [
  {
    label: '交易',
    items: [
      { to: '/dashboard', icon: LayoutDashboard, label: '总览', badge: 'LIVE' },
    ],
  },
  {
    label: '策略',
    items: [
      { to: '/strategies', icon: GitBranch, label: '策略管理' },
      { to: '/backtest', icon: BarChart3, label: '回测中心' },
      { to: '/trades', icon: ArrowLeftRight, label: '交易记录' },
      { to: '/lab', icon: FlaskConical, label: 'RAG 实验室', badge: 'AI' },
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

const W = { collapsed: 64, expanded: 248 }

export function Sidebar() {
  const { data: status } = useSystemStatus()
  const online = status?.api_status === 'connected'
  const isLoading = !status
  const { sidebarCollapsed, sidebarPinned, setSidebarCollapsed, toggleSidebarPinned } = useAppStore()
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined)

  const expanded = !sidebarCollapsed || sidebarPinned
  const width = expanded ? W.expanded : W.collapsed

  const onEnter = useCallback(() => {
    if (sidebarPinned) return
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setSidebarCollapsed(false), 180)
  }, [sidebarPinned, setSidebarCollapsed])

  const onLeave = useCallback(() => {
    if (sidebarPinned) return
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setSidebarCollapsed(true), 280)
  }, [sidebarPinned, setSidebarCollapsed])

  return (
    <aside
      aria-label="主导航"
      onMouseEnter={onEnter}
      onMouseLeave={onLeave}
      className={cn(
        'fixed left-0 top-0 bottom-0 z-50 flex flex-col',
        expanded ? 'sidebar-expanded' : 'sidebar-collapsed',
      )}
      style={{
        width,
        background: 'linear-gradient(180deg, rgba(13,18,16,0.88) 0%, rgba(7,9,8,0.96) 100%)',
        borderRight: '1px solid rgba(189,255,215,0.08)',
        backdropFilter: 'blur(30px) saturate(125%)',
        WebkitBackdropFilter: 'blur(30px) saturate(125%)',
        transition: 'width 0.22s cubic-bezier(0.22, 1, 0.36, 1)',
      }}
    >
      {/* macOS traffic light spacer */}
      <div className="titlebar-space" data-tauri-drag-region />

      {/* Brand */}
      <div
        className="flex items-center shrink-0"
        style={{
          padding: expanded ? '8px 16px 12px' : '8px 0 12px',
          justifyContent: expanded ? 'flex-start' : 'center',
          borderBottom: '1px solid rgba(189,255,215,0.07)',
        }}
      >
        <NavLink to="/dashboard" aria-label="总览" className="flex items-center gap-3 no-drag">
          <PulseDeskLogo size={36} className="shrink-0" />
          {expanded && (
            <div className="sidebar-brand-text">
              <div className="font-mono text-[14px] font-bold tracking-[0.03em]" style={{ color: '#e7f0ea' }}>PulseDesk</div>
              <div className="text-[9px] tracking-[0.06em]" style={{ color: '#5e6a63' }}>AI Trading Workbench</div>
            </div>
          )}
        </NavLink>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-2 py-3 overflow-y-auto overflow-x-hidden no-drag" role="navigation">
        {navSections.map(section => (
          <div key={section.label} className="mb-1">
            <div className="nav-section-label px-3 pb-1.5 pt-4 first:pt-1">
              {expanded && (
                <span className="text-[9px] font-medium uppercase tracking-[0.14em]" style={{ color: '#344038' }}>
                  {section.label}
                </span>
              )}
            </div>
            {section.items.map(({ to, icon: Icon, label, badge }) => (
              <NavLink
                key={to}
                to={to}
                end={to === '/dashboard'}
                className={({ isActive }) => cn('sidebar-nav-item', isActive && 'active')}
              >
                <Icon className="h-[16px] w-[16px] shrink-0" />
                {expanded && (
                  <>
                    <span className="nav-item-label flex-1">{label}</span>
                    {badge && (
                      <span
                        className="nav-item-label text-[9px] px-1.5 py-0.5 rounded"
                        style={{
                          background: 'rgba(140,255,184,0.09)',
                          color: '#8cffb8',
                          border: '1px solid rgba(140,255,184,0.18)',
                        }}
                      >
                        {badge}
                      </span>
                    )}
                  </>
                )}
              </NavLink>
            ))}
          </div>
        ))}
      </nav>

      {/* Status footer */}
      <div
        className="shrink-0 flex items-center gap-2 px-3 py-3 no-drag"
        style={{
          borderTop: '1px solid rgba(189,255,215,0.07)',
          justifyContent: expanded ? 'space-between' : 'center',
        }}
      >
        <span
          className="w-2 h-2 rounded-full shrink-0"
          style={{
            background: isLoading ? '#7db7ff' : online ? '#8cffb8' : '#ff6b6b',
            boxShadow: isLoading
              ? '0 0 10px rgba(125,183,255,0.42)'
              : online
                ? '0 0 10px rgba(140,255,184,0.36)'
                : '0 0 10px rgba(255,107,107,0.42)',
          }}
        />
        {expanded && (
          <>
            <span className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>
              {isLoading ? '同步中...' : online ? '系统在线' : '已离线'}
            </span>
            <button
              onClick={toggleSidebarPinned}
              className={cn('sidebar-pin-btn ml-auto', sidebarPinned && 'pinned')}
              aria-label={sidebarPinned ? '取消固定' : '固定侧边栏'}
            >
              <Pin className="w-3 h-3" />
            </button>
          </>
        )}
      </div>
    </aside>
  )
}
