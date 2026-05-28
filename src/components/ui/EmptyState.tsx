import { type LucideIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Props {
  icon: LucideIcon
  title: string
  description?: string
  action?: {
    label: string
    onClick: () => void
  }
  className?: string
}

export function EmptyState({ icon: Icon, title, description, action, className }: Props) {
  return (
    <div className={cn('flex flex-col items-center justify-center py-12 px-6', className)}>
      <div
        className="w-12 h-12 flex items-center justify-center mb-4"
        style={{
          background: 'rgba(255,255,255,0.04)',
          border: '1px solid rgba(255,255,255,0.06)',
          borderRadius: '8px',
        }}
      >
        <Icon className="w-6 h-6" style={{ color: '#5e6a63' }} />
      </div>
      <h3 className="text-[14px] font-medium text-text-primary mb-1">{title}</h3>
      {description && (
        <p className="text-[12px] font-mono text-text-muted text-center max-w-[280px] mb-4">
          {description}
        </p>
      )}
      {action && (
        <button
          onClick={action.onClick}
          className="btn-primary px-4 py-2 text-[12px]"
        >
          {action.label}
        </button>
      )}
    </div>
  )
}
