import { useState, useEffect, useRef } from 'react'
import { Bell, Check, CheckCheck, AlertTriangle, ArrowLeftRight, Settings } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Notification {
  id: number
  type: string
  title: string
  message: string
  read: boolean
  created_at: string
}

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

const typeIcons: Record<string, React.ElementType> = {
  trade: ArrowLeftRight,
  risk: AlertTriangle,
  system: Settings,
}

const typeColors: Record<string, string> = {
  trade: '#8cffb8',
  risk: '#e8b86d',
  system: '#5e6a63',
}

export function NotificationCenter() {
  const [open, setOpen] = useState(false)
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [unread, setUnread] = useState(0)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const fetchNotifications = async () => {
      try {
        const res = await fetch(`${API_BASE}/notifications`)
        if (res.ok) {
          const data = await res.json()
          setNotifications(data.notifications || [])
          setUnread(data.unread || 0)
        }
      } catch { /* fetch failed */ }
    }

    fetchNotifications()
    const timer = setInterval(fetchNotifications, 30000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const markRead = async (id: number) => {
    try {
      await fetch(`${API_BASE}/notifications/${id}/read`, { method: 'PUT' })
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, read: true } : n))
      )
      setUnread((prev) => Math.max(0, prev - 1))
    } catch { /* mark read failed */ }
  }

  const markAllRead = async () => {
    try {
      await fetch(`${API_BASE}/notifications/read-all`, { method: 'PUT' })
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
      setUnread(0)
    } catch { /* mark all read failed */ }
  }

  return (
    <div ref={menuRef} className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="relative p-1.5 cursor-pointer transition-colors duration-150"
        style={{ color: '#5e6a63', borderRadius: '2px' }}
        aria-label="通知"
      >
        <Bell className="w-3.5 h-3.5" />
        {unread > 0 && (
          <span
            className="absolute top-1 right-1 w-1.5 h-1.5 rounded-full"
            style={{ background: '#ff6b6b' }}
          />
        )}
      </button>

      {open && (
        <div
          className="absolute right-0 top-full mt-2 w-80 z-50"
          style={{
            background: '#111111',
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 16px 48px rgba(0,0,0,0.6)',
            borderRadius: '4px',
          }}
        >
          <div className="flex items-center justify-between px-4 py-3 border-b border-white/6">
            <span className="text-[13px] font-mono font-semibold text-text-primary">通知</span>
            {unread > 0 && (
              <button
                onClick={markAllRead}
                className="text-[11px] font-mono text-primary hover:text-primary-hover transition-colors flex items-center gap-1"
              >
                <CheckCheck className="w-3 h-3" /> 全部已读
              </button>
            )}
          </div>

          <div className="max-h-80 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="px-4 py-8 text-center text-[12px] font-mono" style={{ color: '#5e6a63' }}>
                暂无通知
              </div>
            ) : (
              notifications.map((n) => {
                const Icon = typeIcons[n.type] || Bell
                const color = typeColors[n.type] || '#5e6a63'
                return (
                  <div
                    key={n.id}
                    className={cn(
                      'flex items-start gap-3 px-4 py-3 border-b border-white/4 transition-colors',
                      !n.read && 'bg-white/[0.02]'
                    )}
                  >
                    <div
                      className="w-7 h-7 flex items-center justify-center shrink-0 mt-0.5"
                      style={{ background: `${color}15`, borderRadius: '2px' }}
                    >
                      <Icon className="w-3.5 h-3.5" style={{ color }} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-[12px] font-mono font-medium text-text-primary truncate">
                          {n.title}
                        </span>
                        {!n.read && (
                          <span className="w-1.5 h-1.5 rounded-full shrink-0" style={{ background: '#8cffb8' }} />
                        )}
                      </div>
                      <p className="text-[11px] font-mono text-text-muted mt-0.5 line-clamp-2">{n.message}</p>
                    </div>
                    {!n.read && (
                      <button
                        onClick={() => markRead(n.id)}
                        className="p-1 hover:bg-white/5 rounded shrink-0"
                        title="标记已读"
                      >
                        <Check className="w-3 h-3" style={{ color: '#5e6a63' }} />
                      </button>
                    )}
                  </div>
                )
              })
            )}
          </div>
        </div>
      )}
    </div>
  )
}
