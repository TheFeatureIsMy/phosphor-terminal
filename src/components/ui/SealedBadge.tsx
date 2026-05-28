import { Lock, Unlock } from 'lucide-react'

interface SealedBadgeProps {
  sealed: boolean
  size?: 'sm' | 'md'
}

export function SealedBadge({ sealed, size = 'sm' }: SealedBadgeProps) {
  const iconSize = size === 'sm' ? 'w-2.5 h-2.5' : 'w-3 h-3'
  const textSize = size === 'sm' ? 'text-[10px]' : 'text-[11px]'

  if (sealed) {
    return (
      <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded-sm ${textSize} font-medium`}
        style={{ background: 'rgba(125,183,255,0.08)', color: '#7db7ff', border: '1px solid rgba(125,183,255,0.2)' }}
        title="策略参数已通过 Sealed Inference 加密">
        <Lock className={iconSize} />
        已密封
      </span>
    )
  }

  return (
    <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded-sm ${textSize} font-medium`}
      style={{ background: 'rgba(255,255,255,0.04)', color: '#5e6a63', border: '1px solid rgba(255,255,255,0.08)' }}
      title="策略参数未加密">
      <Unlock className={iconSize} />
      未密封
    </span>
  )
}
