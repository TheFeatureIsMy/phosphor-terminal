import { useState, useCallback, createContext, useContext, type ReactNode } from 'react'
import { X, AlertTriangle, CheckCircle, Info } from 'lucide-react'

type ToastType = 'success' | 'error' | 'info'

interface Toast {
  id: string
  type: ToastType
  message: string
}

interface ToastContextValue {
  toast: (type: ToastType, message: string) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be used within ToastProvider')
  return ctx
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])

  const toast = useCallback((type: ToastType, message: string) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 6)}`
    setToasts(prev => [...prev, { id, type, message }])
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id))
    }, 4000)
  }, [])

  const dismiss = useCallback((id: string) => {
    setToasts(prev => prev.filter(t => t.id !== id))
  }, [])

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="fixed bottom-5 right-5 z-[200] flex flex-col gap-2 pointer-events-none">
        {toasts.map(t => (
          <div
            key={t.id}
            className="pointer-events-auto flex items-center gap-3 px-4 py-3 min-w-[280px] max-w-[400px] animate-in"
            style={{
              background: '#111',
              border: `1px solid ${t.type === 'error' ? 'rgba(255,107,107,0.3)' : t.type === 'success' ? 'rgba(140,255,184,0.3)' : 'rgba(125,183,255,0.3)'}`,
              borderRadius: '2px',
              boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
            }}
          >
            {t.type === 'error' && <AlertTriangle className="w-4 h-4 shrink-0" style={{ color: '#ff6b6b' }} />}
            {t.type === 'success' && <CheckCircle className="w-4 h-4 shrink-0" style={{ color: '#8cffb8' }} />}
            {t.type === 'info' && <Info className="w-4 h-4 shrink-0" style={{ color: '#7db7ff' }} />}
            <span className="flex-1 text-[13px] font-mono" style={{ color: '#e7f0ea' }}>{t.message}</span>
            <button onClick={() => dismiss(t.id)} className="shrink-0 text-text-muted hover:text-text-secondary transition-colors">
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}
