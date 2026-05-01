import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Play, Pause, Trash2, GitBranch } from 'lucide-react'
import { useStrategies, useCreateStrategy, useDeleteStrategy, useUpdateStrategy } from '@/hooks/use-strategies'
import { cn } from '@/lib/utils'
import type { Strategy, StrategyStatus, StrategyType } from '@/types'

const statusConfig: Record<StrategyStatus, { label: string; color: string }> = {
  draft: { label: '草稿', color: 'bg-text-muted/15 text-text-muted' },
  backtested: { label: '已回测', color: 'bg-info/15 text-info' },
  active: { label: '运行中', color: 'bg-success/15 text-success' },
  paused: { label: '已暂停', color: 'bg-warning/15 text-warning' },
  retired: { label: '已退役', color: 'bg-text-muted/15 text-text-muted' },
}

const typeLabels: Record<StrategyType, string> = {
  ma_cross: '均线交叉',
  breakout: '突破策略',
  grid: '网格交易',
  mean_reversion: '均值回归',
  rag_generated: 'RAG生成',
}

export function StrategiesPage() {
  const navigate = useNavigate()
  const { data: strategies, isLoading } = useStrategies()
  const createStrategy = useCreateStrategy()
  const deleteStrategy = useDeleteStrategy()
  const updateStrategy = useUpdateStrategy()
  const [showCreate, setShowCreate] = useState(false)
  const [newName, setNewName] = useState('')

  const handleCreate = () => {
    if (!newName.trim()) return
    createStrategy.mutate({ name: newName, type: 'ma_cross' }, {
      onSuccess: () => { setNewName(''); setShowCreate(false) }
    })
  }

  const handleToggleStatus = (strategy: Strategy) => {
    const newStatus = strategy.status === 'active' ? 'paused' : 'active'
    updateStrategy.mutate({ id: strategy.id, data: { status: newStatus } })
  }

  if (isLoading) return <div className="animate-pulse text-text-muted">Loading strategies...</div>

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">策略管理</h1>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-hover transition-colors"
        >
          <Plus className="w-4 h-4" /> 新建策略
        </button>
      </div>

      {/* Create Strategy Modal */}
      {showCreate && (
        <div className="bg-surface rounded-xl p-5 border border-primary/30">
          <h3 className="text-sm text-text-secondary mb-3">新建策略</h3>
          <div className="flex gap-3">
            <input
              value={newName}
              onChange={e => setNewName(e.target.value)}
              placeholder="策略名称..."
              className="flex-1 px-3 py-2 bg-background border border-border rounded-lg text-text-primary placeholder:text-text-muted focus:outline-none focus:border-primary"
              onKeyDown={e => e.key === 'Enter' && handleCreate()}
            />
            <button onClick={handleCreate} className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-hover">
              创建
            </button>
            <button onClick={() => setShowCreate(false)} className="px-4 py-2 text-text-secondary hover:text-text-primary">
              取消
            </button>
          </div>
        </div>
      )}

      {/* Strategy Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {strategies?.map(strategy => (
          <div key={strategy.id} className="bg-surface rounded-xl p-5 border border-border hover:border-border-hover transition-colors group">
            <div className="flex items-start justify-between mb-3">
              <div>
                <h3 className="font-medium text-text-primary">{strategy.name}</h3>
                <span className="text-xs text-text-muted">{typeLabels[strategy.type]}</span>
              </div>
              <span className={cn('px-2 py-0.5 rounded-full text-xs font-medium', statusConfig[strategy.status].color)}>
                {statusConfig[strategy.status].label}
              </span>
            </div>

            <div className="grid grid-cols-2 gap-3 mb-4">
              <div>
                <span className="text-xs text-text-muted">夏普比率</span>
                <div className="text-lg font-tabular font-medium">{strategy.sharpe_ratio?.toFixed(2) || '--'}</div>
              </div>
              <div>
                <span className="text-xs text-text-muted">最大回撤</span>
                <div className="text-lg font-tabular font-medium text-warning">
                  {strategy.max_drawdown ? `-${strategy.max_drawdown.toFixed(1)}%` : '--'}
                </div>
              </div>
            </div>

            <div className="flex items-center gap-2 text-xs text-text-muted mb-4">
              <span>v{strategy.version}</span>
              <span>·</span>
              <span>{strategy.source === 'manual' ? '手动创建' : strategy.source === 'rag_generated' ? 'RAG生成' : '优化生成'}</span>
            </div>

            <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
              <button
                onClick={() => navigate(`/strategies/${strategy.id}/canvas`)}
                className="flex items-center gap-1 px-3 py-1.5 text-xs bg-background rounded-lg hover:bg-surface-hover text-text-secondary hover:text-text-primary transition-colors"
              >
                <GitBranch className="w-3 h-3" /> 画布
              </button>
              {(strategy.status === 'active' || strategy.status === 'paused') && (
                <button
                  onClick={() => handleToggleStatus(strategy)}
                  className={cn(
                    'flex items-center gap-1 px-3 py-1.5 text-xs rounded-lg transition-colors',
                    strategy.status === 'active'
                      ? 'bg-warning/10 text-warning hover:bg-warning/20'
                      : 'bg-success/10 text-success hover:bg-success/20'
                  )}
                >
                  {strategy.status === 'active' ? <><Pause className="w-3 h-3" /> 暂停</> : <><Play className="w-3 h-3" /> 启动</>}
                </button>
              )}
              <button
                onClick={() => deleteStrategy.mutate(strategy.id)}
                className="flex items-center gap-1 px-3 py-1.5 text-xs bg-danger/10 text-danger rounded-lg hover:bg-danger/20 transition-colors ml-auto"
              >
                <Trash2 className="w-3 h-3" />
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
