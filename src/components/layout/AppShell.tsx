import { Outlet } from 'react-router-dom'
import { TopBar } from './TopBar'
import { Sidebar } from './Sidebar'
import { useAppStore } from '@/stores/app-store'

const TITLEBAR = 52

export function AppShell() {
  const { sidebarCollapsed, sidebarPinned } = useAppStore()
  const sidebarWidth = (!sidebarCollapsed || sidebarPinned) ? 248 : 64

  return (
    <div className="h-dvh w-full overflow-hidden relative" style={{ background: '#070908' }}>
      <a href="#main-content" className="skip-link">跳转到主内容</a>

      <div className="terminal-backdrop" aria-hidden="true" />
      <div className="noise-overlay" aria-hidden="true" />
      <div className="terminal-scanline" aria-hidden="true" />

      <Sidebar />
      <TopBar titlebarHeight={TITLEBAR} />

      <main
        id="main-content"
        className="fixed right-0 bottom-0 z-10 overflow-y-auto overflow-x-hidden"
        style={{
          top: TITLEBAR + 48,
          left: sidebarWidth,
          padding: '24px 28px',
          transition: 'left 0.22s cubic-bezier(0.22, 1, 0.36, 1)',
        }}
        tabIndex={-1}
      >
        <Outlet />
      </main>
    </div>
  )
}
