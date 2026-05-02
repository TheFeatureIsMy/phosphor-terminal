import { Outlet } from 'react-router-dom'
import { TopBar } from './TopBar'

export function AppShell() {
  return (
    <div className="min-h-dvh relative" style={{ background: '#0a0a0a' }}>
      <a href="#main-content" className="skip-link">
        跳转到主内容
      </a>

      {/* Background layers */}
      <div className="bg-mesh" aria-hidden="true" />
      <div className="grid-overlay" aria-hidden="true" />
      <div className="noise-overlay" aria-hidden="true" />

      <TopBar />
      <div className="min-h-dvh flex flex-col relative z-10" style={{ paddingTop: '52px' }}>
        <main id="main-content" className="flex-1 overflow-auto" style={{ padding: '20px 24px' }} tabIndex={-1}>
          <Outlet />
        </main>
      </div>
    </div>
  )
}
