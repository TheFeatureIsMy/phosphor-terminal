import { motion } from 'framer-motion'
import { cn } from '@/lib/utils'

export function AnimatedList<T>({
  items,
  className,
  itemClassName,
  getKey,
  renderItem,
}: {
  items: T[]
  className?: string
  itemClassName?: string
  getKey: (item: T, index: number) => React.Key
  renderItem: (item: T, index: number) => React.ReactNode
}) {
  return (
    <div className={cn('space-y-2', className)}>
      {items.map((item, index) => (
        <motion.div
          key={getKey(item, index)}
          initial={{ opacity: 0, y: 8, filter: 'blur(4px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.28, delay: Math.min(index * 0.035, 0.22), ease: [0.25, 0.46, 0.45, 0.94] }}
          className={itemClassName}
        >
          {renderItem(item, index)}
        </motion.div>
      ))}
    </div>
  )
}
