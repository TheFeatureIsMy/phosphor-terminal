import { cn } from '@/lib/utils'

interface Props {
  size?: 'sm' | 'md' | 'lg'
  className?: string
  label?: string
}

const sizes = {
  sm: 'w-4 h-4',
  md: 'w-6 h-6',
  lg: 'w-8 h-8',
}

export function LoadingSpinner({ size = 'md', className, label }: Props) {
  return (
    <div className={cn('flex flex-col items-center gap-2', className)}>
      <div
        className={cn(
          'border-2 border-white/10 border-t-[#8cffb8] rounded-full animate-spin',
          sizes[size]
        )}
      />
      {label && (
        <span className="text-[12px] font-mono text-text-muted">{label}</span>
      )}
    </div>
  )
}

export function PageLoader() {
  return (
    <div className="flex items-center justify-center h-[60vh]">
      <LoadingSpinner size="lg" label="加载中..." />
    </div>
  )
}

export function InlineLoader({ className }: { className?: string }) {
  return (
    <div className={cn('flex items-center gap-2', className)}>
      <div className="w-3 h-3 border border-white/10 border-t-[#8cffb8] rounded-full animate-spin" />
      <span className="text-[11px] font-mono text-text-muted">加载中...</span>
    </div>
  )
}
