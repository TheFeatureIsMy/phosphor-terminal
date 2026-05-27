import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'

interface Shortcut {
  key: string
  metaKey?: boolean
  ctrlKey?: boolean
  action: () => void
}

export function useKeyboardShortcuts(shortcuts: Shortcut[]) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      for (const shortcut of shortcuts) {
        const metaMatch = shortcut.metaKey ? (e.metaKey || e.ctrlKey) : true
        const keyMatch = e.key.toLowerCase() === shortcut.key.toLowerCase()

        if (keyMatch && metaMatch) {
          e.preventDefault()
          shortcut.action()
          return
        }
      }
    }

    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [shortcuts])
}

export function useGlobalShortcuts() {
  const navigate = useNavigate()

  useKeyboardShortcuts([
    { key: 'k', metaKey: true, action: () => {
      // Trigger search modal - handled by TopBar
      document.dispatchEvent(new CustomEvent('toggle-search'))
    }},
    { key: '1', metaKey: true, action: () => navigate('/dashboard') },
    { key: '2', metaKey: true, action: () => navigate('/strategies') },
    { key: '3', metaKey: true, action: () => navigate('/trades') },
    { key: '4', metaKey: true, action: () => navigate('/backtest') },
    { key: '5', metaKey: true, action: () => navigate('/settings') },
  ])
}
