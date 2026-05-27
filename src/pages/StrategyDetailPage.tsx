import { useState, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  Info, GitBranch, FlaskConical, ArrowLeftRight,
  Play, Pause, BarChart3, AlertTriangle,
  Plus, Database, ArrowLeft, Activity
} from 'lucide-react'
import {
  ReactFlow, Background, Controls, MiniMap,
  addEdge, useNodesState, useEdgesState,
  type Node, type Edge, type OnConnect,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { canvasNodeTypes, defaultCanvasNodes, defaultCanvasEdges, getDefaultNodeData } from '@/components/canvas/CanvasNodes'
import { BacktestResults } from '@/components/shared/BacktestResults'
import { TradesTable } from '@/components/shared/TradesTable'
import { SHAPChart } from '@/components/attribution/SHAPChart'
import { useStrategy, useUpdateStrategy } from '@/hooks/use-strategies'
import { useQuery } from '@tanstack/react-query'
import { runBacktest } from '@/api/dashboard'
import { cn } from '@/lib/utils'
import type { StrategyStatus, StrategyType } from '@/types'

type Tab = 'overview' | 'canvas' | 'backtest' | 'trades' | 'attribution'

const tabs: { id: Tab; label: string; icon: React.ElementType }[] = [
  { id: 'overview', label: '概览', icon: Info },
  { id: 'canvas', label: '画布', icon: GitBranch },
  { id: 'backtest', label: '回测', icon: FlaskConical },
  { id: 'trades', label: '交易记录', icon: ArrowLeftRight },
  { id: 'attribution', label: '归因分析', icon: Activity },
]

const statusConfig: Record<StrategyStatus, { label: string; cls: string }> = {
  draft: { label: '草稿', cls: 'bg-surface-active text-text-muted' },
  backtested: { label: '已回测', cls: 'bg-info/10 text-info' },
  active: { label: '运行中', cls: 'bg-success-dim text-success' },
  paused: { label: '已暂停', cls: 'bg-warning-dim text-warning' },
  retired: { label: '已退役', cls: 'bg-surface-active text-text-muted' },
}

const typeLabels: Record<StrategyType, string> = {
  ma_cross: '均线交叉', breakout: '突破策略', grid: '网格交易',
  mean_reversion: '均值回归', rag_generated: 'RAG生成',
}

export function StrategyDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const strategyId = Number(id)
  const { data: strategy, isLoading } = useStrategy(strategyId)
  const updateStrategy = useUpdateStrategy()
  const [activeTab, setActiveTab] = useState<Tab>('overview')

  const handleToggleStatus = () => {
    if (!strategy) return
    const newStatus = strategy.status === 'active' ? 'paused' : 'active'
    updateStrategy.mutate({ id: strategy.id, data: { status: newStatus } })
  }

  if (isLoading || !strategy) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-text-muted text-sm animate-pulse">加载中...</div>
      </div>
    )
  }

  return (
    <div className="space-y-5">
      {/* Back + Title */}
      <div className="flex items-center gap-3">
        <button onClick={() => navigate('/strategies')} className="btn-ghost p-2">
          <ArrowLeft className="w-4 h-4" />
        </button>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2.5">
            <h1 className="text-xl font-bold font-display truncate">{strategy.name}</h1>
            <span className={cn('badge shrink-0', statusConfig[strategy.status].cls)}>
              {statusConfig[strategy.status].label}
            </span>
          </div>
          <div className="flex items-center gap-2 text-[12px] text-text-muted mt-0.5">
            <span>{typeLabels[strategy.type as StrategyType]}</span>
            <span>·</span>
            <span>{strategy.market}</span>
            <span>·</span>
            <span>v{strategy.version}</span>
          </div>
        </div>
        {(strategy.status === 'active' || strategy.status === 'paused') && (
          <button
            onClick={handleToggleStatus}
            className={cn(
              'flex items-center gap-1.5 px-4 py-2.5 text-[13px] shrink-0',
              strategy.status === 'active' ? 'btn-ghost' : 'btn-primary'
            )}
          >
            {strategy.status === 'active' ? <><Pause className="w-4 h-4" /> 暂停</> : <><Play className="w-4 h-4" /> 启动</>}
          </button>
        )}
      </div>

      {/* Key Metrics Strip */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: '夏普比率', value: strategy.sharpe_ratio?.toFixed(2) || '--', icon: BarChart3, color: '#00ff9d' },
          { label: '最大回撤', value: strategy.max_drawdown ? `-${strategy.max_drawdown.toFixed(1)}%` : '--', icon: AlertTriangle, color: '#ffb800' },
          { label: '交易所', value: strategy.exchange, icon: Database, color: '#00c2ff' },
          { label: '来源', value: strategy.source === 'manual' ? '手动创建' : strategy.source === 'rag_generated' ? 'RAG生成' : '优化生成', icon: GitBranch, color: '#00ff9d' },
        ].map(item => (
          <div key={item.label} className="card px-4 py-3 flex items-center gap-3">
            <div className="w-8 h-8 flex items-center justify-center shrink-0"
              style={{ background: `${item.color}10`, border: `1px solid ${item.color}20`, borderRadius: '2px' }}>
              <item.icon className="w-4 h-4" style={{ color: item.color }} />
            </div>
            <div className="min-w-0">
              <div className="text-[10px] text-text-muted uppercase tracking-wider">{item.label}</div>
              <div className="text-[15px] font-bold font-tabular truncate">{item.value}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Main Content: Sidebar + Tabbed Area */}
      <div className="flex gap-5 items-start">
        {/* Left Sidebar - Parameters & Info */}
        <div className="hidden lg:block w-64 shrink-0 space-y-4 sticky top-20">
          <div className="card p-5 space-y-4">
            <span className="text-[11px] font-semibold tracking-wider uppercase text-text-muted block">策略信息</span>
            <div className="space-y-3">
              <InfoRow label="策略类型" value={typeLabels[strategy.type as StrategyType]} />
              <InfoRow label="交易市场" value={strategy.market} />
              <InfoRow label="交易所" value={strategy.exchange} />
              <InfoRow label="版本" value={`v${strategy.version}`} />
              <InfoRow label="创建时间" value={new Date(strategy.created_at).toLocaleDateString('zh-CN')} />
              <InfoRow label="更新时间" value={new Date(strategy.updated_at).toLocaleDateString('zh-CN')} />
            </div>
          </div>

          {Object.keys(strategy.parameters).length > 0 && (
            <div className="card p-5 space-y-3">
              <span className="text-[11px] font-semibold tracking-wider uppercase text-text-muted block">策略参数</span>
              {Object.entries(strategy.parameters).map(([key, val]) => (
                <div key={key} className="flex items-center justify-between py-1.5 border-b-divider">
                  <span className="text-[12px] text-text-muted">{key}</span>
                  <span className="text-[13px] font-medium font-tabular">{String(val)}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right - Tabbed Content */}
        <div className="flex-1 min-w-0 space-y-5">
          {/* Tab Bar */}
          <div className="flex gap-0" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
            {tabs.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActiveTab(id)}
                className={cn(
                  'flex items-center gap-2 px-4 py-2.5 text-[12px] font-mono font-medium transition-all duration-150 relative',
                  activeTab === id ? 'text-[#e0e0e0]' : 'text-[#555] hover:text-[#888]'
                )}
              >
                {activeTab === id && (
                  <div className="absolute bottom-0 left-0 right-0 h-[2px]" style={{ background: '#00ff9d', boxShadow: '0 0 8px rgba(0,255,157,0.3)' }} />
                )}
                <Icon className="w-3.5 h-3.5" style={{ color: activeTab === id ? '#00ff9d' : undefined }} /> {label}
              </button>
            ))}
          </div>

          {/* Tab Content */}
          {activeTab === 'overview' && <OverviewTab strategy={strategy} />}
          {activeTab === 'canvas' && <CanvasTab />}
          {activeTab === 'backtest' && <BacktestTab strategyId={strategyId} />}
          {activeTab === 'trades' && <TradesTab strategyId={strategyId} />}
          {activeTab === 'attribution' && <SHAPChart strategyId={strategyId} />}
        </div>
      </div>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-[12px] text-text-muted">{label}</span>
      <span className="text-[13px] font-medium">{value}</span>
    </div>
  )
}

// ==================== Overview Tab ====================

function OverviewTab({ strategy }: { strategy: { name: string; type: StrategyType; market: string; exchange: string; version: number; source: string; sharpe_ratio?: number; max_drawdown?: number; created_at: string; updated_at: string; parameters: Record<string, unknown> } }) {
  return (
    <div className="space-y-5">
      {/* Mobile: Show strategy info that's in sidebar on desktop */}
      <div className="lg:hidden card p-5 space-y-3">
        <span className="text-[11px] font-semibold tracking-wider uppercase text-text-muted block">策略信息</span>
        <div className="grid grid-cols-2 gap-3">
          <InfoItem label="策略类型" value={typeLabels[strategy.type as StrategyType]} />
          <InfoItem label="交易市场" value={strategy.market} />
          <InfoItem label="交易所" value={strategy.exchange} />
          <InfoItem label="版本" value={`v${strategy.version}`} />
        </div>
      </div>

      <div className="card p-6 space-y-5">
        <span className="text-[11px] font-semibold tracking-wider uppercase text-text-muted block">核心指标</span>
        <div className="grid grid-cols-2 gap-6">
          <MetricItem label="夏普比率" value={strategy.sharpe_ratio?.toFixed(2) || '--'} />
          <MetricItem label="最大回撤" value={strategy.max_drawdown ? `-${strategy.max_drawdown.toFixed(1)}%` : '--'} color="text-warning" />
        </div>
      </div>

      {Object.keys(strategy.parameters).length > 0 && (
        <div className="card p-6">
          <span className="text-[11px] font-semibold tracking-wider uppercase text-text-muted block mb-5">策略参数</span>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            {Object.entries(strategy.parameters).map(([key, val]) => (
              <div key={key} className="p-3.5 surface-subtle">
                <span className="text-[11px] text-text-muted block mb-1 uppercase tracking-wider">{key}</span>
                <span className="text-[14px] font-medium">{String(val)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function InfoItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <span className="text-[11px] text-text-muted block mb-0.5 uppercase tracking-wider">{label}</span>
      <span className="text-[14px] font-medium">{value}</span>
    </div>
  )
}

function MetricItem({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <div>
      <span className="text-[11px] text-text-muted block mb-0.5 uppercase tracking-wider">{label}</span>
      <span className={cn('text-lg font-semibold font-tabular', color)}>{value}</span>
    </div>
  )
}

// ==================== Canvas Tab ====================

function CanvasTab() {
  const [nodes, , onNodesChange] = useNodesState(defaultCanvasNodes as Node[])
  const [edges, setEdges, onEdgesChange] = useEdgesState(defaultCanvasEdges as Edge[])

  const onConnect: OnConnect = useCallback(
    (params) => setEdges(eds => addEdge({ ...params, animated: true }, eds)),
    [setEdges]
  )

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 flex-wrap">
        <span className="text-[12px] text-text-muted mr-1">添加节点:</span>
        {[
          { type: 'dataSource', label: '数据源', color: 'bg-info/10 text-info' },
          { type: 'indicator', label: '指标', color: 'bg-primary-dim text-primary' },
          { type: 'logicGate', label: '逻辑门', color: 'bg-accent-dim text-accent' },
          { type: 'executor', label: '执行器', color: 'bg-success-dim text-success' },
        ].map(({ type, label, color }) => (
          <button
            key={type}
            className={cn('badge cursor-pointer hover:opacity-80 transition-opacity', color)}
            onClick={() => {
              const newId = `node-${Date.now()}`
              const y = Math.random() * 200 + 50
              onNodesChange([{ type: 'add', item: { id: newId, type, position: { x: 500, y }, data: { label: `新${label}`, ...getDefaultNodeData(type) } } }])
            }}
          >
            <Plus className="w-3 h-3 inline mr-0.5" /> {label}
          </button>
        ))}
      </div>

      <div className="h-[calc(100vh-22rem)] card overflow-hidden">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          nodeTypes={canvasNodeTypes}
          fitView
          deleteKeyCode={['Backspace', 'Delete']}
          className="bg-background"
        >
          <Background color="rgba(255,255,255,0.03)" gap={20} />
          <Controls className="!bg-surface !border-border" />
          <MiniMap
            nodeColor={(node) => {
              switch (node.type) {
                case 'dataSource': return '#00c2ff'
                case 'indicator': return '#00ff9d'
                case 'logicGate': return '#ffb800'
                case 'executor': return '#00ff9d'
                default: return '#334155'
              }
            }}
            className="!bg-surface !border-border"
          />
        </ReactFlow>
      </div>

      <p className="text-[12px] text-text-muted">拖拽节点移动位置，按 Delete 键删除选中节点，从右侧 Handle 拖向左侧 Handle 创建连线</p>
    </div>
  )
}

// ==================== Backtest Tab ====================

const AVAILABLE_SYMBOLS = [
  'BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'SOL/USDT', 'XRP/USDT',
  'ADA/USDT', 'DOGE/USDT', 'AVAX/USDT', 'DOT/USDT', 'MATIC/USDT',
]

function BacktestTab({ strategyId }: { strategyId: number }) {
  const [startDate, setStartDate] = useState('2025-01-01')
  const [endDate, setEndDate] = useState('2025-12-31')
  const [initialCapital, setInitialCapital] = useState(10000)
  const [selectedSymbols, setSelectedSymbols] = useState<string[]>(['BTC/USDT'])
  const [runId, setRunId] = useState(0)

  const toggleSymbol = (symbol: string) => {
    setSelectedSymbols(prev =>
      prev.includes(symbol) ? prev.filter(s => s !== symbol) : [...prev, symbol]
    )
  }

  const { data: backtest, isFetching } = useQuery({
    queryKey: ['backtest', strategyId, runId],
    queryFn: () => runBacktest(strategyId, { start_date: startDate, end_date: endDate, initial_capital: initialCapital, symbols: selectedSymbols }),
    enabled: runId > 0,
  })

  return (
    <div className="space-y-5">
      <div className="card p-6">
        <span className="text-[11px] font-semibold tracking-wider uppercase text-text-muted block mb-5">回测配置</span>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div>
            <label className="text-[12px] text-text-muted block mb-2">开始日期</label>
            <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="w-full px-4 py-2.5 text-[14px]" />
          </div>
          <div>
            <label className="text-[12px] text-text-muted block mb-2">结束日期</label>
            <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="w-full px-4 py-2.5 text-[14px]" />
          </div>
          <div>
            <label className="text-[12px] text-text-muted block mb-2">初始资金 (USDT)</label>
            <input type="number" value={initialCapital} onChange={e => setInitialCapital(Number(e.target.value))} className="w-full px-4 py-2.5 text-[14px] font-tabular" />
          </div>
          <div className="flex items-end">
            <button onClick={() => setRunId(p => p + 1)} disabled={isFetching || selectedSymbols.length === 0} className="btn-primary w-full flex items-center justify-center gap-1.5 px-4 py-2.5 text-[13px] disabled:opacity-50">
              <Play className="w-4 h-4" /> {isFetching ? '运行中...' : '开始回测'}
            </button>
          </div>
        </div>

        <div className="mt-5">
          <label className="text-[12px] text-text-muted block mb-3">交易对 ({selectedSymbols.length} 已选)</label>
          <div className="flex flex-wrap gap-2">
            {AVAILABLE_SYMBOLS.map(symbol => (
              <button
                key={symbol}
                onClick={() => toggleSymbol(symbol)}
                className={cn(
                  'badge cursor-pointer transition-all',
                  selectedSymbols.includes(symbol)
                    ? 'bg-primary-dim text-primary'
                    : 'bg-surface-active text-text-muted hover:text-text-secondary'
                )}
              >
                {symbol}
              </button>
            ))}
          </div>
        </div>
      </div>

      {backtest && <BacktestResults backtest={backtest} />}
    </div>
  )
}

// ==================== Trades Tab ====================

function TradesTab({ strategyId }: { strategyId: number }) {
  return <TradesTable strategyId={strategyId} showStats />
}
