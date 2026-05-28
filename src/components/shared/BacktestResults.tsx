import { TrendingUp, BarChart3, Target, AlertTriangle, Award, Clock } from 'lucide-react'
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { cn, formatPercent, formatCurrency } from '@/lib/utils'
import type { Backtest } from '@/types'

interface BacktestResultsProps {
  backtest: Backtest
}

export function BacktestResults({ backtest }: BacktestResultsProps) {
  return (
    <>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard icon={TrendingUp} label="总收益" value={formatPercent(backtest.total_return)} color="text-profit" />
        <MetricCard icon={BarChart3} label="夏普比率" value={backtest.sharpe_ratio.toFixed(2)} color="text-primary" />
        <MetricCard icon={AlertTriangle} label="最大回撤" value={formatPercent(-backtest.max_drawdown)} color="text-warning" />
        <MetricCard icon={Target} label="胜率" value={formatPercent(backtest.win_rate)} color="text-success" />
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard icon={Award} label="盈亏比" value={backtest.result.metrics.profit_factor.toFixed(2)} />
        <MetricCard icon={BarChart3} label="总交易数" value={String(backtest.result.metrics.total_trades)} />
        <MetricCard icon={Clock} label="平均持仓" value={backtest.result.metrics.avg_trade_duration} />
        <MetricCard icon={TrendingUp} label="最佳单笔" value={formatCurrency(backtest.result.metrics.best_trade)} color="text-profit" />
      </div>

      <div className="card p-6">
        <div className="flex items-center justify-between mb-5">
          <span className="terminal-label">收益曲线</span>
          <span className={cn('badge', backtest.passed ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
            {backtest.passed ? '沙盒通过' : '未通过'}
          </span>
        </div>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={backtest.result.equity_curve}>
            <defs>
              <linearGradient id="btGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={backtest.total_return >= 0 ? '#10b981' : '#ff6b6b'} stopOpacity={0.15} />
                <stop offset="95%" stopColor={backtest.total_return >= 0 ? '#10b981' : '#ff6b6b'} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
            <XAxis dataKey="date" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={v => v.slice(5)} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={v => `$${(v / 1000).toFixed(0)}k`} axisLine={false} tickLine={false} />
            <Tooltip
              contentStyle={{ background: '#111', border: '1px solid rgba(140,255,184,0.15)', borderRadius: 2, color: '#e7f0ea', fontSize: 12, fontFamily: 'IBM Plex Mono' }}
              formatter={(value) => [`$${Number(value).toLocaleString()}`, '资产']}
            />
            <Area type="monotone" dataKey="value" stroke={backtest.total_return >= 0 ? '#10b981' : '#ff6b6b'} fill="url(#btGrad)" strokeWidth={2} dot={false} />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      <div className="card overflow-hidden">
        <div className="px-6 py-4 flex items-center justify-between" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
          <span className="terminal-label">回测交易明细</span>
          <span className="text-[12px] text-text-muted">{backtest.result.trades.length} 笔交易</span>
        </div>
        <div className="overflow-x-auto max-h-64 overflow-y-auto">
          <table className="w-full">
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
                {['时间', '币种', '方向', '数量', '盈亏'].map(h => (
                  <th key={h} className="px-4 py-3 text-[11px] text-text-muted font-semibold tracking-wider uppercase text-left sticky top-0 bg-surface">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {backtest.result.trades.slice(0, 20).map(order => (
                <tr key={order.id} className="table-row" style={{ borderBottom: '1px solid rgba(255,255,255,0.03)' }}>
                  <td className="px-4 py-3 text-[13px] text-text-secondary">
                    {new Date(order.timestamp).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })}
                  </td>
                  <td className="px-4 py-3 text-[13px]">{order.symbol}</td>
                  <td className="px-4 py-3">
                    <span className={cn('badge', order.side === 'BUY' ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                      {order.side}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-[13px] text-right font-tabular">{order.quantity}</td>
                  <td className={cn('px-4 py-3 text-[13px] text-right font-tabular font-medium', getPnlColor(order.profit || 0))}>
                    {order.profit ? formatCurrency(order.profit) : '--'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}

function MetricCard({ icon: Icon, label, value, color }: {
  icon: React.ElementType; label: string; value: string; color?: string
}) {
  return (
    <div className="card p-4">
      <div className="flex items-center gap-1.5 mb-2">
        <Icon className={cn('w-4 h-4', color || 'text-text-muted')} />
        <span className="text-[11px] text-text-muted tracking-wider uppercase">{label}</span>
      </div>
      <div className={cn('text-xl font-semibold font-tabular', color)}>{value}</div>
    </div>
  )
}

function getPnlColor(value: number): string {
  if (value > 0) return 'text-profit'
  if (value < 0) return 'text-loss'
  return 'text-text-secondary'
}
