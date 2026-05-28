interface FeatureBarProps {
  feature: string
  contribution: number
  maxAbs?: number
}

export function FeatureBar({ feature, contribution, maxAbs = 0.5 }: FeatureBarProps) {
  const pct = Math.min(Math.abs(contribution) / maxAbs * 100, 100)
  const isPositive = contribution >= 0
  const color = isPositive ? '#8cffb8' : '#ff6b6b'

  return (
    <div className="flex items-center gap-3 mb-2.5">
      <span className="text-[10px] font-mono w-20 shrink-0" style={{ color: '#9aa8a0' }}>
        {feature}
      </span>
      <div className="flex-1 h-1.5 overflow-hidden" style={{ background: 'rgba(255,255,255,0.05)', borderRadius: '1px' }}>
        <div
          className="h-full transition-all duration-700"
          style={{
            width: `${pct}%`,
            background: color,
            borderRadius: '1px',
          }}
        />
      </div>
      <span className="text-[10px] font-tabular font-medium w-14 text-right" style={{ color }}>
        {isPositive ? '+' : ''}{contribution?.toFixed(3) ?? '0.000'}
      </span>
    </div>
  )
}
