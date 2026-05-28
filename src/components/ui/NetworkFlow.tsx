import { Database, Cpu, ShieldCheck, Gem, Link2, Blocks } from 'lucide-react'
import { cn } from '@/lib/utils'

const nodes = [
  { label: '数据源', icon: Database, color: '#7db7ff' },
  { label: '策略引擎', icon: Link2, color: '#8cffb8' },
  { label: '风控层', icon: ShieldCheck, color: '#e8b86d' },
  { label: '执行器', icon: Cpu, color: '#06b6d4' },
  { label: '归因分析', icon: Blocks, color: '#a855f7' },
  { label: 'AI进化', icon: Gem, color: '#f59e0b' },
]

export function NetworkFlow({ className }: { className?: string }) {
  return (
    <div className={cn('relative min-h-[138px] overflow-hidden rounded-lg border border-white/[0.05] bg-white/[0.015] p-4', className)}>
      <div className="absolute inset-0 opacity-50" style={{
        backgroundImage: 'radial-gradient(circle at 1px 1px, rgba(255,255,255,0.08) 1px, transparent 0)',
        backgroundSize: '18px 18px',
      }} />
      <svg className="absolute inset-0 h-full w-full" viewBox="0 0 720 140" preserveAspectRatio="none" aria-hidden="true">
        <path d="M62 70 C150 22 205 118 300 70 S445 22 535 70 S635 112 665 70" fill="none" stroke="rgba(140,255,184,0.15)" strokeWidth="1.2" />
        <path className="cq-flow-line" d="M62 70 C150 22 205 118 300 70 S445 22 535 70 S635 112 665 70" fill="none" stroke="rgba(140,255,184,0.75)" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
      <div className="relative z-10 flex h-[106px] items-center justify-between gap-3">
        {nodes.map((node) => (
          <div key={node.label} className="flex flex-col items-center gap-2">
            <div
              className="flex h-11 w-11 items-center justify-center rounded-md border"
              style={{ background: `${node.color}12`, borderColor: `${node.color}35`, boxShadow: `0 0 18px ${node.color}18` }}
            >
              <node.icon className="h-5 w-5" style={{ color: node.color }} />
            </div>
            <span className="font-mono text-[10px] tracking-[0.08em]" style={{ color: '#9aa8a0' }}>{node.label}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
