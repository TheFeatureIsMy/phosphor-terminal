export function PageSkeleton() {
  return (
    <div className="space-y-5 animate-pulse">
      <div className="flex items-center justify-between">
        <div className="skeleton h-7 w-32" />
        <div className="skeleton h-9 w-24" />
      </div>
      <div className="grid grid-cols-3 gap-4">
        <div className="card p-5"><div className="skeleton h-16" /></div>
        <div className="card p-5"><div className="skeleton h-16" /></div>
        <div className="card p-5"><div className="skeleton h-16" /></div>
      </div>
      <div className="card p-6"><div className="skeleton h-64" /></div>
    </div>
  )
}

export function TableSkeleton({ rows = 5, cols = 5 }: { rows?: number; cols?: number }) {
  return (
    <div className="card overflow-hidden animate-pulse">
      <div className="px-4 py-3 border-b-divider">
        <div className="skeleton h-4 w-24" />
      </div>
      <div className="divide-y divide-border">
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i} className="px-4 py-3 flex items-center gap-4">
            {Array.from({ length: cols }).map((_, j) => (
              <div key={j} className="skeleton h-4 flex-1" />
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}

export function CardSkeleton() {
  return (
    <div className="card p-5 animate-pulse">
      <div className="skeleton h-4 w-20 mb-3" />
      <div className="skeleton h-8 w-28" />
    </div>
  )
}
