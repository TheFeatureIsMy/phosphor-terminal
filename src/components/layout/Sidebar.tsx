import { NavLink } from 'react-router-dom'
import { motion } from 'framer-motion'
import {
  LayoutDashboard, GitBranch, FlaskConical, ArrowLeftRight,
  Settings, Activity, ChevronLeft, ChevronRight
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { useAppStore } from '@/stores/app-store'

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/strategies', icon: GitBranch, label: '策略管理' },
  { to: '/backtest', icon: FlaskConical, label: '回测中心' },
  { to: '/trades', icon: ArrowLeftRight, label: '交易记录' },
  { to: '/settings', icon: Settings, label: '系统设置' },
]

export function Sidebar() {
  const { sidebarCollapsed, toggleSidebar } = useAppStore()

  return (
    <motion.aside
      animate={{ width: sidebarCollapsed ? 64 : 240 }}
      transition={{ duration: 0.2 }}
      className="fixed left-0 top-0 h-screen bg-surface border-r border-border flex flex-col z-50"
    >
      {/* Logo */}
      <div className="h-16 flex items-center px-4 border-b border-border">
        <Activity className="w-6 h-6 text-primary shrink-0" />
        {!sidebarCollapsed && (
          <span className="ml-3 font-bold text-lg text-text-primary whitespace-nowrap">
            CyberQuant OS
          </span>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4 space-y-1 px-2">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) => cn(
              'flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors',
              isActive
                ? 'bg-primary/15 text-primary'
                : 'text-text-secondary hover:text-text-primary hover:bg-surface-hover'
            )}
          >
            <Icon className="w-5 h-5 shrink-0" />
            {!sidebarCollapsed && <span className="whitespace-nowrap">{label}</span>}
          </NavLink>
        ))}
      </nav>

      {/* Collapse Toggle */}
      <button
        onClick={toggleSidebar}
        className="h-12 flex items-center justify-center border-t border-border text-text-muted hover:text-text-primary transition-colors"
      >
        {sidebarCollapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
      </button>
    </motion.aside>
  )
}
