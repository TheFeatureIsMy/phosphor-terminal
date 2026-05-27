import { useEffect, useState } from 'react'
import { cn } from '@/lib/utils'

interface Props {
  children: React.ReactNode
  delay?: number
  duration?: number
  className?: string
}

export function FadeIn({ children, delay = 0, duration = 300, className }: Props) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setVisible(true), delay)
    return () => clearTimeout(timer)
  }, [delay])

  return (
    <div
      className={cn('transition-opacity', className)}
      style={{
        opacity: visible ? 1 : 0,
        transitionDuration: `${duration}ms`,
      }}
    >
      {children}
    </div>
  )
}

export function SlideIn({
  children,
  direction = 'up',
  delay = 0,
  duration = 300,
  className,
}: Props & { direction?: 'up' | 'down' | 'left' | 'right' }) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setVisible(true), delay)
    return () => clearTimeout(timer)
  }, [delay])

  const transforms = {
    up: visible ? 'translateY(0)' : 'translateY(10px)',
    down: visible ? 'translateY(0)' : 'translateY(-10px)',
    left: visible ? 'translateX(0)' : 'translateX(10px)',
    right: visible ? 'translateX(0)' : 'translateX(-10px)',
  }

  return (
    <div
      className={cn('transition-all', className)}
      style={{
        opacity: visible ? 1 : 0,
        transform: transforms[direction],
        transitionDuration: `${duration}ms`,
      }}
    >
      {children}
    </div>
  )
}
