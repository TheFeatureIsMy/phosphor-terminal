import { useState } from 'react'
import { Play, TrendingUp, BarChart3, Target, Clock, Award, AlertTriangle } from 'lucide-react'
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useStrategies } from '@/hooks/use-strategies'
import { useQuery } from '@tanstack/react-query'
import { runBacktest } from '@/api/dashboard'
import { cn, formatPercent, formatCurrency } from '@/lib/utils'

export function BacktestPage() {
  const { data: strategies } = useStrategies()
  const [selectedStrategy, setSelectedStrategy] = useState<number>(1)
  const [startDate, setStartDate] = useState('2025-01-01')
  const [endDate, setEndDate] = useState('2025-12-31')
  const [initialCapital, setInitialCapital] = useState(10000)
  const [runId, setRunId] = useState(0)

  const { data: backtest, isFetching } = useQuery({
    queryKey: ['backtest', runId],
    queryFn: () => runBacktest(selectedStrategy, { start_date: startDate, end_date: endDate, initial_capital: initialCapital }),
    enabled: runId > 0,
  })

  const handleRun = () => setRunId(prev => prev + 1)

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">回测中心</h1>

      {/* Config Panel */}
      <div className="bg-surface rounded-xl p-5 border border-border">
        <h3 className="text-sm text-text-secondary mb-4">回测配置</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <div>
            <label className="text-xs text-text-muted block mb-1">策略</label>
            <select
              value={selectedStrategy}
              onChange={e => setSelectedStrategy(Number(e.target.value))}
              className="w-full px-3 py-2 bg-background border border-border rounded-lg text-text-primary focus:outline-none focus:border-primary"
            >
              {strategies?.map(s => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs text-text-muted block mb-1">开始日期</label>
            <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)}
              className="w-full px-3 py-2 bg-background border border-border rounded-lg text-text-primary focus:outline-none focus:border-primary" />
          </div>
          <div>
            <label className="text-xs text-text-muted block mb-1">结束日期</label>
            <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)}
              className="w-full px-3 py-2 bg-background border border-border rounded-lg text-text-primary focus:outline-none focus:border-primary" />
          </div>
          <div>
            <label className="text-xs text-text-muted block mb-1">初始资金 (USDT)</label>
            <input type="number" value={initialCapital} onChange={e => setInitialCapital(Number(e.target.value))}
              className="w-full px-3 py-2 bg-background border border-border rounded-lg text-text-primary focus:outline-none focus:border-primary" />
          </div>
          <div className="flex items-end">
            <button
              onClick={handleRun}
              disabled={isFetching}
              className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-hover disabled:opacity-50 transition-colors"
            >
              <Play className="w-4 h-4" />
              {isFetching ? '运行中...' : '开始回测'}
            </button>
          </div>
        </div>
      </div>

      {/* Results */}
      {backtest && (
        <>
          {/* Metrics */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <MetricCard icon={TrendingUp} label="总收益" value={formatPercent(backtest.total_return)} color="text-profit" />
            <MetricCard icon={BarChart3} label="夏普比率" value={backtest.sharpe_ratio.toFixed(2)} color="text-info" />
            <MetricCard icon={AlertTriangle} label="最大回撤" value={formatPercent(-backtest.max_drawdown)} color="text-warning" />
            <MetricCard icon={Target} label="胜率" value={formatPercent(backtest.win_rate)} color="text-success" />
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <MetricCard icon={Award} label="盈亏比" value={backtest.result.metrics.profit_factor.toFixed(2)} />
            <MetricCard icon={BarChart3} label="总交易数" value={String(backtest.result.metrics.total_trades)} />
            <MetricCard icon={Clock} label="平均持仓" value={backtest.result.metrics.avg_trade_duration} />
            <MetricCard icon={TrendingUp} label="最佳单笔" value={formatCurrency(backtest.result.metrics.best_trade)} color="text-profit" />
          </div>

          {/* Equity Curve */}
          <div className="bg-surface rounded-xl p-5 border border-border">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm text-text-secondary">收益曲线</h3>
              <span className={cn('px-2 py-0.5 rounded text-xs font-medium', backtest.passed ? 'bg-success/15 text-success' : 'bg-danger/15 text-danger')}>
                {backtest.passed ? '沙盒通过' : '未通过'}
              </span>
            </div>
            <ResponsiveContainer width="100%" height={350}>
              <AreaChart data={backtest.result.equity_curve}>
                <defs>
                  <linearGradient id="btGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={backtest.total_return >= 0 ? '#10b981' : '#ef4444'} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={backtest.total_return >= 0 ? '#10b981' : '#ef4444'} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#1f2937" />
                <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} tickFormatter={v => v.slice(5)} />
                <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} tickFormatter={v => `$${(v/1000).toFixed(0)}k`} />
                <Tooltip
                  contentStyle={{ background: '#111827', border: '1px solid #1f2937', borderRadius: 8, color: '#f9fafb' }}
                  formatter={(value) => [`$${Number(value).toLocaleString()}`, '资产']}
                />
                <Area type="monotone" dataKey="value" stroke={backtest.total_return >= 0 ? '#10b981' : '#ef4444'} fill="url(#btGradient)" strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </>
      )}
    </div>
  )
}

function MetricCard({ icon: Icon, label, value, color }: {
  icon: React.ElementType; label: string; value: string; color?: string
}) {
  return (
    <div className="bg-surface rounded-xl p-4 border border-border">
      <div className="flex items-center gap-2 mb-2">
        <Icon className={cn('w-4 h-4', color || 'text-text-muted')} />
        <span className="text-xs text-text-secondary">{label}</span>
      </div>
      <div className={cn('text-xl font-bold font-tabular', color)}>{value}</div>
    </div>
  )
}
