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

  return (
    <div className="space-y-5">
      <h1 className="text-lg font-semibold text-text-primary">回测中心</h1>

      <div className="card p-4">
        <span className="text-xs text-text-muted tracking-wider uppercase">回测配置</span>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-3 mt-3">
          <div>
            <label className="text-[11px] text-text-muted block mb-1">策略</label>
            <select value={selectedStrategy} onChange={e => setSelectedStrategy(Number(e.target.value))} className="w-full px-3 py-2 text-sm">
              {strategies?.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </div>
          <div>
            <label className="text-[11px] text-text-muted block mb-1">开始日期</label>
            <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="w-full px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="text-[11px] text-text-muted block mb-1">结束日期</label>
            <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="w-full px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="text-[11px] text-text-muted block mb-1">初始资金 (USDT)</label>
            <input type="number" value={initialCapital} onChange={e => setInitialCapital(Number(e.target.value))} className="w-full px-3 py-2 text-sm font-mono" />
          </div>
          <div className="flex items-end">
            <button onClick={() => setRunId(p => p + 1)} disabled={isFetching} className="btn-primary w-full flex items-center justify-center gap-1.5 px-4 py-2 text-sm disabled:opacity-50">
              <Play className="w-3.5 h-3.5" /> {isFetching ? '运行中...' : '开始回测'}
            </button>
          </div>
        </div>
      </div>

      {backtest && (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
            <MetricCard icon={TrendingUp} label="总收益" value={formatPercent(backtest.total_return)} color="text-profit" />
            <MetricCard icon={BarChart3} label="夏普比率" value={backtest.sharpe_ratio.toFixed(2)} color="text-primary" />
            <MetricCard icon={AlertTriangle} label="最大回撤" value={formatPercent(-backtest.max_drawdown)} color="text-warning" />
            <MetricCard icon={Target} label="胜率" value={formatPercent(backtest.win_rate)} color="text-success" />
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
            <MetricCard icon={Award} label="盈亏比" value={backtest.result.metrics.profit_factor.toFixed(2)} />
            <MetricCard icon={BarChart3} label="总交易数" value={String(backtest.result.metrics.total_trades)} />
            <MetricCard icon={Clock} label="平均持仓" value={backtest.result.metrics.avg_trade_duration} />
            <MetricCard icon={TrendingUp} label="最佳单笔" value={formatCurrency(backtest.result.metrics.best_trade)} color="text-profit" />
          </div>

          <div className="card p-4">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs text-text-muted tracking-wider uppercase">收益曲线</span>
              <span className={cn('badge', backtest.passed ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                {backtest.passed ? '沙盒通过' : '未通过'}
              </span>
            </div>
            <ResponsiveContainer width="100%" height={320}>
              <AreaChart data={backtest.result.equity_curve}>
                <defs>
                  <linearGradient id="btGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={backtest.total_return >= 0 ? '#34d399' : '#f87171'} stopOpacity={0.12} />
                    <stop offset="95%" stopColor={backtest.total_return >= 0 ? '#34d399' : '#f87171'} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                <XAxis dataKey="date" tick={{ fill: '#4a5068', fontSize: 10, fontFamily: 'JetBrains Mono' }} tickFormatter={v => v.slice(5)} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#4a5068', fontSize: 10, fontFamily: 'JetBrains Mono' }} tickFormatter={v => `$${(v/1000).toFixed(0)}k`} axisLine={false} tickLine={false} />
                <Tooltip
                  contentStyle={{ background: '#1a1b28', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 10, color: '#e2e8f0', fontFamily: 'JetBrains Mono', fontSize: 11 }}
                  formatter={(value) => [`$${Number(value).toLocaleString()}`, '资产']}
                />
                <Area type="monotone" dataKey="value" stroke={backtest.total_return >= 0 ? '#34d399' : '#f87171'} fill="url(#btGrad)" strokeWidth={1.5} dot={false} />
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
    <div className="card p-3.5">
      <div className="flex items-center gap-1.5 mb-1.5">
        <Icon className={cn('w-3.5 h-3.5', color || 'text-text-muted')} />
        <span className="text-[11px] text-text-muted tracking-wider uppercase">{label}</span>
      </div>
      <div className={cn('text-lg font-semibold font-tabular', color)}>{value}</div>
    </div>
  )
}
