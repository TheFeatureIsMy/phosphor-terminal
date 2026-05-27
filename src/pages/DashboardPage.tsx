import { BarChart3, TrendingUp, TrendingDown } from 'lucide-react'
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useDashboardKPIs, useEquityCurve, useOrders, usePositions, useCorrelationMatrix } from '@/hooks/use-dashboard'
import { cn, formatCurrency, formatPercent, getPnlColor } from '@/lib/utils'
import { PageHeader } from '@/components/ui/PageHeader'
import { SentimentDashboard } from '@/components/sentiment/SentimentDashboard'

export function DashboardPage() {
  const { data: kpis, isLoading: kpiLoading } = useDashboardKPIs()
  const { data: equityCurve } = useEquityCurve()
  const { data: orders } = useOrders(10)
  const { data: positions } = usePositions()
  const { data: correlation } = useCorrelationMatrix()

  return (
    <div className="space-y-5">
      <PageHeader title="总览" />

      {kpiLoading || !kpis ? (
        <div className="space-y-5">
          <div className="grid grid-cols-1 lg:grid-cols-[1.5fr_1fr] gap-4">
            <div className="card p-6"><div className="skeleton h-32" /></div>
            <div className="grid grid-cols-2 grid-rows-2 gap-3"><div className="card p-4"><div className="skeleton h-16" /></div><div className="card p-4"><div className="skeleton h-16" /></div><div className="card p-4"><div className="skeleton h-16" /></div><div className="card p-4"><div className="skeleton h-16" /></div></div>
          </div>
          <div className="card p-6"><div className="skeleton h-[280px]" /></div>
        </div>
      ) : (
        <>
          {/* ===== HERO: Large PnL + 2x2 Metrics ===== */}
          <div className="grid grid-cols-1 lg:grid-cols-[1.5fr_1fr] gap-4">
            {/* Hero Card - Total PnL */}
            <div className="card p-6 relative overflow-hidden">
              <div className="absolute top-0 right-0 w-48 h-48 opacity-5"
                style={{ background: 'radial-gradient(circle, var(--color-primary), transparent)', filter: 'blur(60px)' }} />
              <div className="relative">
                <div className="flex items-center gap-2.5 mb-5">
                  <div className="icon-box" style={{ background: 'var(--color-primary-dim)', border: '1px solid var(--color-primary-15)' }}>
                    <BarChart3 className="w-3.5 h-3.5 text-primary" />
                  </div>
                  <span className="terminal-label">总盈亏</span>
                </div>
                <div className="text-4xl font-bold font-tabular tracking-tight mb-2 font-display text-text-primary">{formatCurrency(kpis.total_pnl)}</div>
                <div className={cn('text-[13px] font-tabular font-medium flex items-center gap-1.5', getPnlColor(kpis.pnl_change_pct))}>
                  {kpis.pnl_change_pct >= 0 ? <TrendingUp className="w-3.5 h-3.5" /> : <TrendingDown className="w-3.5 h-3.5" />}
                  {formatPercent(kpis.pnl_change_pct)} <span className="text-text-muted text-[11px]">vs 上期</span>
                </div>
              </div>
            </div>

            {/* 2x2 Metrics Grid */}
            <div className="grid grid-cols-2 gap-3">
              <div className="card p-4 flex flex-col justify-between">
                <div className="terminal-label">胜率</div>
                <div>
                  <div className="text-xl font-bold font-tabular">{formatPercent(kpis.win_rate)}</div>
                  <div className="w-full h-1 mt-2 overflow-hidden bg-surface" style={{ borderRadius: '1px' }}>
                    <div className="h-full bg-primary" style={{ width: `${kpis.win_rate * 100}%`, borderRadius: '1px' }} />
                  </div>
                </div>
              </div>
              <div className="card p-4 flex flex-col justify-between">
                <div className="terminal-label">最大回撤</div>
                <div>
                  <div className="text-xl font-bold font-tabular text-warning">{formatPercent(-kpis.max_drawdown)}</div>
                  <div className="text-[10px] font-mono mt-1 text-text-muted">阈值: 15%</div>
                </div>
              </div>
              <div className="card p-4">
                <div className="terminal-label mb-1.5">夏普比率</div>
                <div className="text-xl font-bold font-tabular">{kpis.sharpe_ratio.toFixed(2)}</div>
              </div>
              <div className="card p-4">
                <div className="terminal-label mb-1.5">活跃策略</div>
                <div className="text-xl font-bold font-tabular text-primary">{kpis.active_strategies}</div>
              </div>
            </div>
          </div>

          {/* ===== CHART (FULL WIDTH) ===== */}
          <div className="card p-6">
            <div className="flex items-center justify-between mb-5">
              <div className="flex items-center gap-2">
                <span className="terminal-label">收益曲线</span>
                <span className="text-[10px] font-mono text-text-muted">90D</span>
              </div>
              <div className="flex items-center gap-4">
                <div className="flex items-center gap-1.5">
                  <div className="w-2 h-2 bg-primary" style={{ borderRadius: '1px' }} />
                  <span className="text-[10px] font-mono text-text-muted">资产</span>
                </div>
                <span className="text-[13px] font-bold font-tabular text-primary">
                  {formatCurrency(kpis.total_pnl * 0.08)} <span className="text-[10px] font-mono font-normal text-text-muted">今日</span>
                </span>
              </div>
            </div>
            {equityCurve && equityCurve.length > 0 ? (
              <ResponsiveContainer width="100%" height={260}>
                <AreaChart data={equityCurve} aria-label="收益曲线图表">
                  <defs>
                    <linearGradient id="equityGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#00ff9d" stopOpacity={0.15} />
                      <stop offset="95%" stopColor="#00ff9d" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" />
                  <XAxis dataKey="date" tick={{ fill: '#555', fontSize: 10, fontFamily: 'IBM Plex Mono' }} tickFormatter={v => v.slice(5)} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fill: '#555', fontSize: 10, fontFamily: 'IBM Plex Mono' }} tickFormatter={v => `$${(v/1000).toFixed(0)}k`} axisLine={false} tickLine={false} />
                  <Tooltip
                    contentStyle={{ background: '#111', border: '1px solid rgba(0,255,157,0.15)', borderRadius: 2, color: '#e0e0e0', fontSize: 12, fontFamily: 'IBM Plex Mono' }}
                    formatter={(value) => [`$${Number(value).toLocaleString()}`, '资产']}
                  />
                  <Area type="monotone" dataKey="value" stroke="#00ff9d" fill="url(#equityGrad)" strokeWidth={1.5} dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex items-center justify-center h-[260px] text-text-muted text-sm font-mono">暂无收益数据</div>
            )}
          </div>

          {/* ===== BOTTOM: Trades table + Positions ===== */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            {/* Trades Table - 2/3 width */}
            <div className="lg:col-span-2 card overflow-hidden">
              <div className="px-5 py-3 flex items-center justify-between border-b-divider">
                <span className="terminal-label">最近交易</span>
                <span className="text-[10px] font-mono text-text-muted">{orders?.length || 0} 笔</span>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b-divider">
                      {['币种', '方向', '时间', '盈亏'].map(h => (
                        <th key={h} className="px-5 py-2.5 text-[10px] text-text-muted font-mono font-medium tracking-wider uppercase text-left">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {orders && orders.length > 0 ? orders.slice(0, 8).map(order => (
                      <tr key={order.id} className="table-row" style={{ borderBottom: '1px solid rgba(255,255,255,0.03)' }}>
                        <td className="px-5 py-2.5 text-[13px] font-medium font-mono">{order.symbol}</td>
                        <td className="px-5 py-2.5">
                          <span className={cn('badge', order.side === 'BUY' ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                            {order.side}
                          </span>
                        </td>
                        <td className="px-5 py-2.5 text-[12px] text-text-muted font-mono">
                          {new Date(order.timestamp).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                        </td>
                        <td className={cn('px-5 py-2.5 text-[13px] font-tabular font-medium text-right', getPnlColor(order.profit || 0))}>
                          {order.profit ? formatCurrency(order.profit) : '--'}
                        </td>
                      </tr>
                    )) : (
                      <tr><td colSpan={4} className="px-5 py-10 text-center text-text-muted font-mono text-[12px]">暂无交易记录</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Right sidebar: Positions */}
            <div className="card p-5">
              <span className="terminal-label block mb-3">当前持仓</span>
              <div className="space-y-2">
                {positions && positions.length > 0 ? positions.slice(0, 5).map(pos => (
                  <div key={pos.id} className="flex items-center justify-between p-3 surface-subtle">
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5">
                        <span className="text-[13px] font-medium font-mono">{pos.symbol}</span>
                        <span className={cn('badge text-[9px]', pos.side === 'long' ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                          {pos.side.toUpperCase()}
                        </span>
                      </div>
                      <div className="text-[11px] font-mono mt-0.5 text-text-muted">{pos.quantity} @ ${pos.avg_price.toLocaleString()}</div>
                    </div>
                    <div className={cn('text-[13px] font-tabular font-medium text-right', getPnlColor(pos.unrealized_pnl))}>
                      {formatCurrency(pos.unrealized_pnl)}
                    </div>
                  </div>
                )) : (
                  <div className="py-6 text-center text-text-muted text-[12px] font-mono">暂无持仓</div>
                )}
              </div>
            </div>
          </div>

          {/* Correlation Matrix */}
          {correlation && correlation.length > 0 && (
            <div className="card p-6">
              <span className="terminal-label block mb-4">相关性矩阵</span>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                {correlation.map(c => {
                  const corrColor = c.correlation > 0.85 ? 'text-danger' : c.correlation > 0.7 ? 'text-warning' : 'text-success'
                  const barColor = c.correlation > 0.85 ? 'var(--color-danger)' : c.correlation > 0.7 ? 'var(--color-warning)' : 'var(--color-primary)'
                  return (
                    <div key={c.id} className="flex items-center justify-between p-3 surface-subtle">
                      <div className="flex items-center gap-1.5 text-[13px] min-w-0 truncate font-mono">
                        <span className="font-medium">{c.symbol_a}</span>
                        <span className="text-text-muted">/</span>
                        <span className="font-medium">{c.symbol_b}</span>
                      </div>
                      <div className="flex items-center gap-2.5 shrink-0 ml-3">
                        <div className="w-16 h-1 overflow-hidden bg-surface" style={{ borderRadius: '1px' }}>
                          <div className="h-full" style={{ width: `${c.correlation * 100}%`, background: barColor, borderRadius: '1px' }} />
                        </div>
                        <span className={cn('text-[13px] font-tabular font-medium w-10 text-right', corrColor)}>
                          {c.correlation.toFixed(2)}
                        </span>
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          )}

          {/* Market Sentiment */}
          <SentimentDashboard />
        </>
      )}
    </div>
  )
}
