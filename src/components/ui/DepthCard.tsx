import { useRef, useState } from 'react'
import { cn } from '@/lib/utils'

type DepthCardProps = React.PropsWithChildren<{
  className?: string
  contentClassName?: string
  maxRotation?: number
  spotlightColor?: string
  disabled?: boolean
  onClick?: () => void
}>

export function DepthCard({
  children,
  className,
  contentClassName,
  maxRotation = 1.4,
  spotlightColor = 'rgba(140,255,184,0.045)',
  disabled,
  onClick,
}: DepthCardProps) {
  const ref = useRef<HTMLDivElement>(null)
  const [style, setStyle] = useState<React.CSSProperties>({})
  const [spotlight, setSpotlight] = useState<React.CSSProperties>({ opacity: 0 })

  const reset = () => {
    setStyle({ transform: 'perspective(1100px) rotateX(0deg) rotateY(0deg) translateY(0)' })
    setSpotlight({ opacity: 0 })
  }

  const handleMove = (event: React.MouseEvent<HTMLDivElement>) => {
    if (disabled || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const rect = ref.current?.getBoundingClientRect()
    if (!rect) return
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    const px = x / rect.width
    const py = y / rect.height
    const rotateY = (px - 0.5) * maxRotation * 2
    const rotateX = (0.5 - py) * maxRotation * 2
    setStyle({
      transform: `perspective(1100px) rotateX(${rotateX.toFixed(2)}deg) rotateY(${rotateY.toFixed(2)}deg) translateY(-1px)`,
    })
    setSpotlight({
      opacity: 1,
      background: `radial-gradient(320px circle at ${x}px ${y}px, ${spotlightColor}, transparent 46%)`,
    })
  }

  return (
    <div
      ref={ref}
      onMouseMove={handleMove}
      onMouseLeave={reset}
      onClick={onClick}
      className={cn('depth-card card relative overflow-hidden transition-transform duration-200 ease-out', className)}
      style={style}
    >
      <div className="pointer-events-none absolute inset-0 transition-opacity duration-200" style={spotlight} />
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-primary/20 to-transparent" />
      <div className={cn('relative z-10', contentClassName)}>
        {children}
      </div>
    </div>
  )
}
