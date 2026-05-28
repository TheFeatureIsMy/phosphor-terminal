import { Database, FlaskConical, WifiOff } from 'lucide-react'
import type { DataSourceStatus } from '@/types'

interface DataSourceBadgeProps {
  source?: DataSourceStatus | null
  compact?: boolean
}

export function DataSourceBadge({ source, compact = false }: DataSourceBadgeProps) {
  if (!source) return null

  const isSimulated = source.simulated || source.source === 'simulated'
  const isUnavailable = !source.available || source.source === 'unavailable'
  const Icon = isUnavailable ? WifiOff : isSimulated ? FlaskConical : Database
  const label = isUnavailable ? 'UNAVAILABLE' : isSimulated ? 'SIMULATED' : source.source.toUpperCase()
  const color = isUnavailable ? '#ff6b6b' : isSimulated ? '#e8b86d' : '#8cffb8'

  return (
    <span
      className="inline-flex items-center gap-1 rounded px-2 py-1 font-mono text-[9px] leading-none"
      title={source.detail || label}
      style={{
        color,
        background: `${color}12`,
        border: `1px solid ${color}30`,
      }}
    >
      <Icon className="h-3 w-3" />
      {!compact && label}
    </span>
  )
}
