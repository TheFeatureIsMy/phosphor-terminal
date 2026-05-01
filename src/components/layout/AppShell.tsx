import { Outlet } from 'react-router-dom'
import { motion } from 'framer-motion'
import { Sidebar } from './Sidebar'
import { TopBar } from './TopBar'
import { useAppStore } from '@/stores/app-store'

export function AppShell() {
  const { sidebarCollapsed } = useAppStore()

  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <motion.div
        animate={{ marginLeft: sidebarCollapsed ? 64 : 240 }}
        transition={{ duration: 0.2 }}
        className="min-h-screen flex flex-col"
      >
        <TopBar />
        <main className="flex-1 p-6 overflow-auto">
          <Outlet />
        </main>
      </motion.div>
    </div>
  )
}
