import { cn } from '@/lib/utils'

type BadgeVariant = 'default' | 'success' | 'warning' | 'danger' | 'info'

interface Props {
  variant?: BadgeVariant
  children: React.ReactNode
  className?: string
}

const variants: Record<BadgeVariant, string> = {
  default: 'bg-surface-active text-text-muted',
  success: 'bg-success-dim text-success',
  warning: 'bg-warning-dim text-warning',
  danger: 'bg-danger-dim text-danger',
  info: 'bg-info/10 text-info',
}

export function Badge({ variant = 'default', children, className }: Props) {
  return (
    <span
      className={cn(
        'inline-flex items-center px-2 py-0.5 text-[10px] font-mono font-medium rounded',
        variants[variant],
        className
      )}
    >
      {children}
    </span>
  )
}
