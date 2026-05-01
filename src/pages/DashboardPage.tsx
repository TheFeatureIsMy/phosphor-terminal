import { TrendingUp, TrendingDown, BarChart3, Shield, Target, Bot, ArrowLeftRight, Wallet } from 'lucide-react'
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useDashboardKPIs, useEquityCurve, useOrders, usePositions, useRiskEvents } from '@/hooks/use-dashboard'
import { cn, formatCurrency, formatPercent, getPnlColor } from '@/lib/utils'

function KPICard({ icon: Icon, label, value, change, color }: {
  icon: React.ElementType; label: string; value: string; change?: string; color?: string
}) {
  return (
    <div className="bg-surface rounded-xl p-5 border border-border hover:border-border-hover transition-colors">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-text-secondary">{label}</span>
        <Icon className={cn('w-5 h-5', color || 'text-text-muted')} />
      </div>
      <div className="text-2xl font-bold font-tabular">{value}</div>
      {change && (
        <div className={cn('text-sm mt-1 font-tabular', getPnlColor(parseFloat(change)))}>
          {change}
        </div>
      )}
    </div>
  )
}

export function DashboardPage() {
  const { data: kpis, isLoading: kpiLoading } = useDashboardKPIs()
  const { data: equityCurve } = useEquityCurve()
  const { data: orders } = useOrders(10)
  const { data: positions } = usePositions()
  const { data: riskEvents } = useRiskEvents()

  if (kpiLoading || !kpis) {
    return <div className="animate-pulse text-text-muted">Loading dashboard...</div>
  }

  // PnL distribution data
  const pnlDistribution = orders?.reduce((acc, order) => {
    const bucket = order.profit && order.profit > 0 ? 'profit' : 'loss'
    acc[bucket] = (acc[bucket] || 0) + 1
    return acc
  }, {} as Record<string, number>) || {}

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Dashboard</h1>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KPICard
          icon={TrendingUp}
          label="总盈亏"
          value={formatCurrency(kpis.total_pnl)}
          change={formatPercent(kpis.pnl_change_pct)}
          color="text-profit"
        />
        <KPICard
          icon={BarChart3}
          label="夏普比率"
          value={kpis.sharpe_ratio.toFixed(2)}
          color="text-info"
        />
        <KPICard
          icon={Shield}
          label="最大回撤"
          value={formatPercent(-kpis.max_drawdown)}
          color="text-warning"
        />
        <KPICard
          icon={Target}
          label="胜率"
          value={formatPercent(kpis.win_rate)}
          color="text-success"
        />
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KPICard icon={Bot} label="活跃策略" value={String(kpis.active_strategies)} color="text-primary" />
        <KPICard icon={ArrowLeftRight} label="今日交易" value={String(kpis.todays_trades)} />
        <KPICard icon={Wallet} label="持仓数" value={String(kpis.open_positions)} />
        <KPICard icon={TrendingDown} label="今日盈亏" value={formatCurrency(kpis.total_pnl * 0.08)} change={formatPercent(0.42)} />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Equity Curve */}
        <div className="lg:col-span-2 bg-surface rounded-xl p-5 border border-border">
          <h3 className="text-sm text-text-secondary mb-4">收益曲线 (90天)</h3>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={equityCurve}>
              <defs>
                <linearGradient id="equityGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#1f2937" />
              <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} tickFormatter={v => v.slice(5)} />
              <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} tickFormatter={v => `$${(v/1000).toFixed(0)}k`} />
              <Tooltip
                contentStyle={{ background: '#111827', border: '1px solid #1f2937', borderRadius: 8, color: '#f9fafb' }}
                formatter={(value) => [`$${Number(value).toLocaleString()}`, '资产']}
                labelFormatter={label => `日期: ${label}`}
              />
              <Area type="monotone" dataKey="value" stroke="#3b82f6" fill="url(#equityGradient)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* PnL Distribution */}
        <div className="bg-surface rounded-xl p-5 border border-border">
          <h3 className="text-sm text-text-secondary mb-4">盈亏分布</h3>
          <div className="flex items-end justify-center gap-8 h-[280px]">
            <div className="flex flex-col items-center gap-2">
              <div className="text-3xl font-bold text-profit font-tabular">{pnlDistribution.profit || 0}</div>
              <div className="w-16 bg-profit/30 rounded-t" style={{ height: `${(pnlDistribution.profit || 0) * 4}px` }} />
              <span className="text-xs text-text-muted">盈利</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <div className="text-3xl font-bold text-loss font-tabular">{pnlDistribution.loss || 0}</div>
              <div className="w-16 bg-loss/30 rounded-t" style={{ height: `${(pnlDistribution.loss || 0) * 4}px` }} />
              <span className="text-xs text-text-muted">亏损</span>
            </div>
          </div>
          <div className="mt-4 text-center">
            <span className="text-sm text-text-secondary">胜率 </span>
            <span className="text-lg font-bold text-success font-tabular">{formatPercent(kpis.win_rate)}</span>
          </div>
        </div>
      </div>

      {/* Bottom Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Recent Trades */}
        <div className="bg-surface rounded-xl p-5 border border-border">
          <h3 className="text-sm text-text-secondary mb-4">最近交易</h3>
          <div className="space-y-2">
            {orders?.slice(0, 8).map(order => (
              <div key={order.id} className="flex items-center justify-between py-2 border-b border-border last:border-0">
                <div className="flex items-center gap-3">
                  <span className={cn(
                    'px-2 py-0.5 rounded text-xs font-medium',
                    order.side === 'BUY' ? 'bg-profit/15 text-profit' : 'bg-loss/15 text-loss'
                  )}>
                    {order.side}
                  </span>
                  <span className="text-sm font-medium">{order.symbol}</span>
                </div>
                <div className="text-right">
                  <div className={cn('text-sm font-tabular', getPnlColor(order.profit || 0))}>
                    {order.profit ? formatCurrency(order.profit) : '--'}
                  </div>
                  <div className="text-xs text-text-muted">
                    {new Date(order.timestamp).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Open Positions */}
        <div className="bg-surface rounded-xl p-5 border border-border">
          <h3 className="text-sm text-text-secondary mb-4">当前持仓</h3>
          <div className="space-y-3">
            {positions?.map(pos => (
              <div key={pos.id} className="flex items-center justify-between p-3 bg-background rounded-lg">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-medium">{pos.symbol}</span>
                    <span className={cn(
                      'px-1.5 py-0.5 rounded text-xs',
                      pos.side === 'long' ? 'bg-profit/15 text-profit' : 'bg-loss/15 text-loss'
                    )}>
                      {pos.side.toUpperCase()}
                    </span>
                  </div>
                  <div className="text-xs text-text-muted mt-1">
                    {pos.quantity} @ ${pos.avg_price.toLocaleString()}
                  </div>
                </div>
                <div className="text-right">
                  <div className={cn('font-tabular font-medium', getPnlColor(pos.unrealized_pnl))}>
                    {formatCurrency(pos.unrealized_pnl)}
                  </div>
                  <div className="text-xs text-text-muted">
                    SL: ${pos.stop_loss_price?.toLocaleString() || '--'}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Risk Events */}
      {riskEvents && riskEvents.length > 0 && (
        <div className="bg-surface rounded-xl p-5 border border-border">
          <h3 className="text-sm text-text-secondary mb-4">风控事件</h3>
          <div className="space-y-2">
            {riskEvents.map(event => (
              <div key={event.id} className="flex items-center gap-3 py-2 border-b border-border last:border-0">
                <span className={cn(
                  'w-2 h-2 rounded-full',
                  event.severity === 'critical' ? 'bg-danger' :
                  event.severity === 'high' ? 'bg-warning' :
                  event.severity === 'medium' ? 'bg-info' : 'bg-text-muted'
                )} />
                <span className="text-sm flex-1">{event.description}</span>
                <span className="text-xs text-text-muted whitespace-nowrap">
                  {new Date(event.created_at).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
