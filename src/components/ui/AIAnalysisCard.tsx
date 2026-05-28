import { Sparkles, TrendingUp, AlertTriangle, Wrench, Database } from 'lucide-react'

export interface AIAdvice {
  type: 'buy' | 'risk' | 'optimize' | 'info'
  title: string
  content: string
}

const tagConfig: Record<AIAdvice['type'], { bg: string; color: string; border: string; icon: React.ElementType }> = {
  buy: {
    bg: 'rgba(140,255,184,0.1)',
    color: '#8cffb8',
    border: 'rgba(140,255,184,0.2)',
    icon: TrendingUp,
  },
  risk: {
    bg: 'rgba(255,107,107,0.1)',
    color: '#ff6b6b',
    border: 'rgba(255,107,107,0.2)',
    icon: AlertTriangle,
  },
  optimize: {
    bg: 'rgba(245,158,11,0.1)',
    color: '#f59e0b',
    border: 'rgba(245,158,11,0.2)',
    icon: Wrench,
  },
  info: {
    bg: 'rgba(6,182,212,0.1)',
    color: '#06b6d4',
    border: 'rgba(6,182,212,0.2)',
    icon: Database,
  },
}

interface AIAnalysisCardProps {
  advice: AIAdvice[]
  confidence?: number
  verified?: boolean
  title?: string
}

export function AIAnalysisCard({
  advice,
  confidence = 78,
  verified = true,
  title = 'AI 分析建议',
}: AIAnalysisCardProps) {
  return (
    <div
      style={{
        background: 'rgba(140,255,184,0.02)',
        border: '1px solid rgba(140,255,184,0.1)',
        borderRadius: '6px',
        padding: '18px 20px',
        backdropFilter: 'blur(14px)',
        WebkitBackdropFilter: 'blur(14px)',
      }}
    >
      <div className="flex items-center gap-2.5 mb-4">
        <div className="w-1.5 h-1.5 rounded-full" style={{ background: '#8cffb8', boxShadow: '0 0 6px rgba(140,255,184,0.5)' }} />
        <h4 className="text-[12px] font-bold tracking-wider font-mono" style={{ color: '#8cffb8' }}>
          {title}
        </h4>
        {verified && (
          <span
            className="text-[9px] font-mono px-1.5 py-0.5"
            style={{
              background: 'rgba(140,255,184,0.08)',
              color: '#8cffb8',
              border: '1px solid rgba(140,255,184,0.15)',
              borderRadius: '2px',
            }}
          >
            VERIFIED
          </span>
        )}
      </div>

      <div className="space-y-3">
        {advice.map((item, i) => {
          const cfg = tagConfig[item.type]
          const Icon = cfg.icon
          return (
            <div
              key={i}
              className="flex items-start gap-3"
              style={{
                paddingBottom: i < advice.length - 1 ? '12px' : '0',
                borderBottom: i < advice.length - 1 ? '1px solid rgba(255,255,255,0.03)' : 'none',
              }}
            >
              <span
                className="inline-flex items-center gap-1 px-2 py-0.5 text-[9px] font-mono font-semibold shrink-0 mt-0.5"
                style={{ background: cfg.bg, color: cfg.color, border: `1px solid ${cfg.border}`, borderRadius: '2px' }}
              >
                <Icon className="w-2.5 h-2.5" />
                {item.title}
              </span>
              <span className="text-[11px] leading-relaxed" style={{ color: '#c0c0c0' }}>
                {item.content}
              </span>
            </div>
          )
        })}
      </div>

      <div className="flex items-center justify-between mt-4 pt-3" style={{ borderTop: '1px solid rgba(255,255,255,0.04)' }}>
        <span className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>
          模型置信度: {confidence}%
        </span>
        <span
          className="inline-flex items-center gap-1 text-[9px] font-mono px-1.5 py-0.5"
          style={{
            background: 'rgba(140,255,184,0.08)',
            color: '#8cffb8',
            border: '1px solid rgba(140,255,184,0.15)',
            borderRadius: '2px',
          }}
        >
          <Sparkles className="w-2.5 h-2.5" />
          AI POWERED
        </span>
      </div>
    </div>
  )
}
