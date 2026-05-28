import { useState, useEffect } from 'react'

interface SystemMetrics {
  cpu_usage: number
  mem_usage: number
  network_rx: number
  network_tx: number
}

export function useTauriMetrics(intervalMs = 3000) {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null)

  useEffect(() => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const tauri = (window as any).__TAURI_INTERNALS__
    if (!tauri?.invoke) return

    let active = true

    const poll = async () => {
      try {
        const data = await tauri.invoke('get_system_metrics')
        if (active) setMetrics(data)
      } catch {
        // ignore
      }
    }

    poll()
    const id = setInterval(poll, intervalMs)
    return () => { active = false; clearInterval(id) }
  }, [intervalMs])

  return metrics
}
