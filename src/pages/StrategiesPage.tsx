import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Play, Pause, Trash2, TrendingUp, GitBranch, BarChart3, AlertTriangle, ArrowRight } from 'lucide-react'
import { useStrategies, useCreateStrategy, useDeleteStrategy, useUpdateStrategy } from '@/hooks/use-strategies'
import { PageHeader } from '@/components/ui/PageHeader'
import { useToast } from '@/components/ui/Toast'
import { CardSkeleton } from '@/components/ui/Skeleton'
import { DepthCard } from '@/components/ui/DepthCard'
import { cn } from '@/lib/utils'
import type { Strategy, StrategyStatus, StrategyType } from '@/types'

const statusConfig: Record<StrategyStatus, { label: string; cls: string; dot: string; bg: string }> = {
  draft: { label: '草稿', cls: 'text-text-muted', dot: '#5e6a63', bg: 'rgba(255,255,255,0.04)' },
  backtested: { label: '已回测', cls: 'text-info', dot: '#7db7ff', bg: 'rgba(125,183,255,0.08)' },
  active: { label: '运行中', cls: 'text-success', dot: '#8cffb8', bg: 'rgba(140,255,184,0.08)' },
  paused: { label: '已暂停', cls: 'text-warning', dot: '#e8b86d', bg: 'rgba(232,184,109,0.08)' },
  retired: { label: '已退役', cls: 'text-text-muted', dot: '#5e6a63', bg: 'rgba(255,255,255,0.04)' },
}

const typeLabels: Record<StrategyType, string> = {
  ma_cross: '均线交叉', breakout: '突破策略', grid: '网格交易',
  mean_reversion: '均值回归', rag_generated: 'RAG生成',
}

const typeColors: Record<StrategyType, string> = {
  ma_cross: '#8cffb8', breakout: '#7db7ff', grid: '#e8b86d',
  mean_reversion: '#ff6b6b', rag_generated: '#8cffb8',
}

export function StrategiesPage() {
  const navigate = useNavigate()
  const { toast } = useToast()
  const { data: strategies, isLoading } = useStrategies()
  const createStrategy = useCreateStrategy()
  const deleteStrategy = useDeleteStrategy()
  const updateStrategy = useUpdateStrategy()
  const [showCreate, setShowCreate] = useState(false)
  const [newName, setNewName] = useState('')

  const handleCreate = () => {
    if (!newName.trim()) return
    createStrategy.mutate({ name: newName, type: 'ma_cross' }, {
      onSuccess: () => { setNewName(''); setShowCreate(false); toast('success', '策略创建成功') },
      onError: (err) => toast('error', `创建失败: ${err.message}`),
    })
  }

  const handleToggleStatus = (e: React.MouseEvent, strategy: Strategy) => {
    e.stopPropagation()
    const newStatus = strategy.status === 'active' ? 'paused' : 'active'
    updateStrategy.mutate(
      { id: strategy.id, data: { status: newStatus } },
      { onError: (err) => toast('error', `操作失败: ${err.message}`) },
    )
  }

  if (isLoading) return (
    <div className="space-y-6">
      <PageHeader title="策略管理" />
      <div className="grid grid-cols-3 gap-4">
        <CardSkeleton /><CardSkeleton /><CardSkeleton />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        <CardSkeleton /><CardSkeleton /><CardSkeleton />
      </div>
    </div>
  )

  const activeCount = strategies?.filter(s => s.status === 'active').length || 0
  const totalCount = strategies?.length || 0

  return (
    <div className="space-y-6">
      <PageHeader
        title="策略管理"
        actions={
          <button onClick={() => setShowCreate(true)} className="btn-primary flex items-center gap-2 px-5 py-2.5 text-[12px]">
            <Plus className="w-4 h-4" /> 新建策略
          </button>
        }
      />

      {/* Stats modules */}
      <div className="grid grid-cols-3 gap-4 stagger">
        <DepthCard className="animate-in p-5 flex items-center gap-4">
          <div className="w-10 h-10 flex items-center justify-center" style={{ background: 'rgba(140,255,184,0.06)', border: '1px solid rgba(140,255,184,0.12)', borderRadius: '2px' }}>
            <GitBranch className="w-4 h-4" style={{ color: '#8cffb8' }} />
          </div>
          <div>
            <div className="terminal-label">总策略</div>
            <div className="text-2xl font-bold font-tabular">{totalCount}</div>
          </div>
        </DepthCard>
        <DepthCard className="animate-in p-5 flex items-center gap-4">
          <div className="w-10 h-10 flex items-center justify-center" style={{ background: 'rgba(140,255,184,0.06)', border: '1px solid rgba(140,255,184,0.12)', borderRadius: '2px' }}>
            <Play className="w-4 h-4" style={{ color: '#8cffb8' }} />
          </div>
          <div>
            <div className="terminal-label">运行中</div>
            <div className="text-2xl font-bold font-tabular" style={{ color: '#8cffb8' }}>{activeCount}</div>
          </div>
        </DepthCard>
        <DepthCard className="animate-in p-5 flex items-center gap-4">
          <div className="w-10 h-10 flex items-center justify-center" style={{ background: 'rgba(232,184,109,0.06)', border: '1px solid rgba(232,184,109,0.12)', borderRadius: '2px' }}>
            <TrendingUp className="w-4 h-4" style={{ color: '#e8b86d' }} />
          </div>
          <div>
            <div className="terminal-label">平均夏普</div>
            <div className="text-2xl font-bold font-tabular">
              {strategies && strategies.length > 0
                ? (strategies.reduce((s, st) => s + (st.sharpe_ratio || 0), 0) / strategies.length).toFixed(2)
                : '--'}
            </div>
          </div>
        </DepthCard>
      </div>

      {/* Create form */}
      {showCreate && (
        <div className="card p-5" style={{ border: '1px solid rgba(140,255,184,0.2)' }}>
          <div className="flex gap-3">
            <input
              value={newName}
              onChange={e => setNewName(e.target.value)}
              placeholder="输入策略名称..."
              className="flex-1 px-4 py-2.5 text-[13px] font-mono"
              onKeyDown={e => e.key === 'Enter' && handleCreate()}
            />
            <button onClick={handleCreate} className="btn-primary px-5 py-2.5 text-[12px]">创建</button>
            <button onClick={() => setShowCreate(false)} className="btn-ghost px-5 py-2.5 text-[12px]">取消</button>
          </div>
        </div>
      )}

      {/* Strategy card grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 stagger">
        {strategies?.map(strategy => {
          const sc = statusConfig[strategy.status]
          const tc = typeColors[strategy.type] || '#8cffb8'
          return (
            <DepthCard
              key={strategy.id}
              className="animate-in p-5 cursor-pointer"
              onClick={() => navigate(`/strategies/${strategy.id}`)}
            >
              {/* Header: Type badge + Status */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 flex items-center justify-center" style={{ background: `${tc}10`, border: `1px solid ${tc}20`, borderRadius: '2px' }}>
                    <GitBranch className="w-3.5 h-3.5" style={{ color: tc }} />
                  </div>
                  <span className="text-[10px] font-mono font-medium px-2 py-0.5 uppercase tracking-wider" style={{ background: `${tc}10`, color: tc, borderRadius: '2px' }}>
                    {typeLabels[strategy.type]}
                  </span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-1.5 h-1.5 rounded-full" style={{ background: sc.dot, boxShadow: `0 0 6px ${sc.dot}40` }} />
                  <span className={cn('text-[11px] font-mono font-medium', sc.cls)}>{sc.label}</span>
                </div>
              </div>

              {/* Name */}
              <h3 className="text-[15px] font-semibold font-mono mb-1 truncate" style={{ color: '#e7f0ea' }}>{strategy.name}</h3>
              <div className="flex items-center gap-2 text-[11px] font-mono mb-5" style={{ color: '#5e6a63' }}>
                <span>{strategy.exchange}</span>
                <span>·</span>
                <span>v{strategy.version}</span>
                <span>·</span>
                <span>{strategy.source === 'manual' ? '手动' : strategy.source === 'rag_generated' ? 'RAG' : '优化'}</span>
              </div>

              {/* Metrics row */}
              <div className="grid grid-cols-2 gap-3 mb-4">
                <div className="p-3" style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.04)', borderRadius: '2px' }}>
                  <div className="flex items-center gap-1.5 mb-1">
                    <BarChart3 className="w-3 h-3" style={{ color: '#8cffb8' }} />
                    <span className="terminal-label" style={{ fontSize: '9px' }}>夏普</span>
                  </div>
                  <div className="text-lg font-bold font-tabular">{strategy.sharpe_ratio?.toFixed(2) || '--'}</div>
                </div>
                <div className="p-3" style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.04)', borderRadius: '2px' }}>
                  <div className="flex items-center gap-1.5 mb-1">
                    <AlertTriangle className="w-3 h-3" style={{ color: '#e8b86d' }} />
                    <span className="terminal-label" style={{ fontSize: '9px' }}>回撤</span>
                  </div>
                  <div className="text-lg font-bold font-tabular" style={{ color: '#e8b86d' }}>
                    {strategy.max_drawdown ? `-${strategy.max_drawdown.toFixed(1)}%` : '--'}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center justify-between pt-3" style={{ borderTop: '1px solid rgba(255,255,255,0.04)' }}>
                <div className="flex items-center gap-2">
                  {(strategy.status === 'active' || strategy.status === 'paused') && (
                    <button
                      onClick={(e) => handleToggleStatus(e, strategy)}
                      className={cn(
                        'flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-mono font-medium transition-colors',
                        strategy.status === 'active' ? 'bg-warning-dim text-warning' : 'bg-success-dim text-success'
                      )}
                      style={{ borderRadius: '2px' }}
                    >
                      {strategy.status === 'active' ? <><Pause className="w-3 h-3" /> 暂停</> : <><Play className="w-3 h-3" /> 启动</>}
                    </button>
                  )}
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      deleteStrategy.mutate(strategy.id, {
                        onSuccess: () => toast('success', '策略已删除'),
                        onError: (err) => toast('error', `删除失败: ${err.message}`),
                      })
                    }}
                    className="p-1.5 text-text-muted hover:text-danger transition-colors"
                    style={{ borderRadius: '2px' }}
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
                <ArrowRight className="w-4 h-4 text-text-muted group-hover:text-primary transition-colors" />
              </div>
            </DepthCard>
          )
        })}
      </div>
    </div>
  )
}
