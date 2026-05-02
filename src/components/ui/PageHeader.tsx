import { ChevronRight } from 'lucide-react'
import { Link } from 'react-router-dom'
import { cn } from '@/lib/utils'

interface BreadcrumbItem {
  label: string
  href?: string
}

interface PageHeaderProps {
  title: string
  breadcrumbs?: BreadcrumbItem[]
  actions?: React.ReactNode
  className?: string
}

export function PageHeader({ title, breadcrumbs, actions, className }: PageHeaderProps) {
  return (
    <div className={cn('flex items-center justify-between mb-6', className)}>
      <div className="min-w-0">
        {breadcrumbs && breadcrumbs.length > 0 && (
          <nav className="flex items-center gap-1.5 mb-1">
            {breadcrumbs.map((item, i) => (
              <span key={i} className="flex items-center gap-1.5">
                {i > 0 && <ChevronRight className="w-3 h-3 text-text-muted" />}
                {item.href ? (
                  <Link to={item.href} className="text-[11px] cursor-pointer text-text-muted hover:text-primary transition-colors">
                    {item.label}
                  </Link>
                ) : (
                  <span className="text-[11px] text-text-muted">{item.label}</span>
                )}
              </span>
            ))}
          </nav>
        )}
        <div className="flex items-center gap-3">
          <span className="text-[11px] font-mono tracking-wider" style={{ color: 'rgba(0,255,157,0.4)' }}>//</span>
          <h1 className="text-xl font-bold tracking-tight" style={{ fontFamily: 'Instrument Sans, sans-serif', color: '#e0e0e0' }}>
            {title}
          </h1>
        </div>
      </div>
      {actions && <div className="shrink-0 ml-4">{actions}</div>}
    </div>
  )
}
