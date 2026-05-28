import { TrendingUp, TrendingDown } from 'lucide-react'
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { useDashboardKPIs, useEquityCurve, useOrders, usePositions, useCorrelationMatrix } from '@/hooks/use-dashboard'
import { cn, formatCurrency, getPnlColor } from '@/lib/utils'
import { SentimentDashboard } from '@/components/sentiment/SentimentDashboard'
import { NetworkFlow } from '@/components/ui/NetworkFlow'
import { AnimatedList } from '@/components/ui/AnimatedList'
import CountUp from '@/components/ui/count-up'
import { DepthCard } from '@/components/ui/DepthCard'
import BlurText from '@/components/ui/blur-text'

const dataSources = [
  { label: 'OHLCV', desc: 'Binance K线数据', color: '#8cffb8', status: 'LIVE' },
  { label: 'Orderbook', desc: 'L2/L3 深度数据', color: '#7db7ff', status: 'LIVE' },
  { label: 'News', desc: 'CryptoPanic 新闻流', color: '#e8b86d', status: 'LIVE' },
  { label: 'Social', desc: 'Reddit/X 情绪分析', color: '#a855f7', status: 'BETA' },
  { label: 'On-chain', desc: '链上鲸鱼交易追踪', color: '#06b6d4', status: 'MOCK' },
  { label: 'Macro', desc: 'DXY/VIX/SPY 宏观指标', color: '#f59e0b', status: 'LIVE' },
]

function KpiCard({ label, value, suffix, color, sub }: {
  label: string; value: number; suffix?: string; color?: string; sub?: React.ReactNode
}) {
  return (
    <DepthCard className="p-5">
      <div className="terminal-label mb-3">{label}</div>
      <div className="text-[1.8rem] font-bold font-tabular leading-none" style={{ fontFamily: 'Instrument Sans, sans-serif', color: color || '#f2fff6' }}>
        <CountUp to={value} duration={1.5} separator="," />{suffix}
      </div>
      {sub && <div className="mt-2">{sub}</div>}
    </DepthCard>
  )
}

export function DashboardPage() {
  const { data: kpis, isLoading: kpiLoading } = useDashboardKPIs()
  const { data: equityCurve } = useEquityCurve()
  const { data: orders } = useOrders(10)
  const { data: positions } = usePositions()
  const { data: correlation } = useCorrelationMatrix()

  if (kpiLoading || !kpis) {
    return (
      <div className="space-y-6">
        <div className="mb-4">
          <div className="skeleton h-8 w-32 mb-2" />
          <div className="skeleton h-4 w-48" />
        </div>
        <div className="grid grid-cols-4 gap-4">
          {[1,2,3,4].map(i => <div key={i} className="card p-5"><div className="skeleton h-24" /></div>)}
        </div>
        <div className="card p-6"><div className="skeleton h-[280px]" /></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="mb-2">
        <BlurText
          text="交易总览"
          className="text-2xl font-bold tracking-tight"
          style={{ fontFamily: 'Instrument Sans, sans-serif', color: '#f2fff6' }}
        />
        <p className="text-[12px] mt-1 font-mono" style={{ color: '#5e6a63' }}>
          实时交易数据与系统运行状态
        </p>
      </div>

      {/* Primary KPIs — 4 column */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4 stagger">
        <KpiCard
          label="总盈亏"
          value={kpis.total_pnl}
          sub={
            <div className={cn('text-[11px] flex items-center gap-1 font-tabular', getPnlColor(kpis.pnl_change_pct))}>
              {kpis.pnl_change_pct >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
              <CountUp to={Math.abs(kpis.pnl_change_pct)} duration={1.2} />%
              <span style={{ color: '#5e6a63', marginLeft: 4 }}>vs 上期</span>
            </div>
          }
        />
        <KpiCard label="夏普比率" value={kpis.sharpe_ratio} sub={<span className="text-[11px] font-mono" style={{ color: '#5e6a63' }}>滚动30天</span>} />
        <KpiCard label="最大回撤" value={kpis.max_drawdown} suffix="%" color="#e8b86d" sub={<span className="text-[11px] font-mono" style={{ color: '#5e6a63' }}>阈值: 15%</span>} />
        <DepthCard className="p-5">
          <div className="terminal-label mb-3">胜率</div>
          <div className="text-[1.8rem] font-bold font-tabular leading-none" style={{ fontFamily: 'Instrument Sans, sans-serif' }}>
            <CountUp to={kpis.win_rate} duration={1.2} />%
          </div>
          <div className="mt-3 h-1.5 overflow-hidden rounded-full" style={{ background: 'rgba(255,255,255,0.04)' }}>
            <div className="h-full rounded-full transition-all duration-1000" style={{ width: `${kpis.win_rate}%`, background: 'linear-gradient(90deg, #8cffb8, #7db7ff)' }} />
          </div>
        </DepthCard>
      </div>

      {/* Secondary KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 stagger">
        {[
          { label: '活跃策略', value: kpis.active_strategies, color: '#8cffb8' },
          { label: '今日交易', value: kpis.todays_trades },
          { label: '持仓数量', value: kpis.open_positions },
          { label: '系统状态', value: 1, color: '#8cffb8', display: '运行中' },
        ].map((item, i) => (
          <div key={i} className="card p-4 animate-in" style={{ borderRadius: 10 }}>
            <div className="terminal-label mb-2" style={{ fontSize: '9px' }}>{item.label}</div>
            <div className="text-xl font-bold font-tabular" style={{ color: item.color || '#e7f0ea' }}>
              {item.display || <CountUp to={item.value} duration={1} />}
            </div>
          </div>
        ))}
      </div>

      {/* Sentiment + Equity */}
      <div className="grid grid-cols-1 xl:grid-cols-[2fr_1fr] gap-4">
        <SentimentDashboard />
        <DepthCard className="p-5">
          <div className="flex items-center justify-between mb-4">
            <span className="terminal-label">收益曲线 · 90D</span>
            <span className="text-[13px] font-bold font-tabular" style={{ color: '#8cffb8' }}>
              <CountUp to={kpis.total_pnl * 0.08} duration={1.2} separator="," />
              <span className="text-[10px] font-mono font-normal ml-1" style={{ color: '#5e6a63' }}>今日</span>
            </span>
          </div>
          {equityCurve && equityCurve.length > 0 ? (
            <ResponsiveContainer width="100%" height={220}>
              <AreaChart data={equityCurve} aria-label="收益曲线">
                <defs>
                  <linearGradient id="eqGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#8cffb8" stopOpacity={0.12} />
                    <stop offset="95%" stopColor="#8cffb8" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.025)" />
                <XAxis dataKey="date" tick={{ fill: '#5e6a63', fontSize: 10, fontFamily: 'IBM Plex Mono' }} tickFormatter={v => v.slice(5)} axisLine={false} tickLine={false} />
                <YAxis hide />
                <Tooltip contentStyle={{ background: 'rgba(18,18,24,0.95)', border: '1px solid rgba(140,255,184,0.12)', borderRadius: 8, color: '#e7f0ea', fontSize: 12, fontFamily: 'IBM Plex Mono', backdropFilter: 'blur(20px)' }} formatter={(value) => [`$${Number(value).toLocaleString()}`, '资产']} />
                <Area type="monotone" dataKey="value" stroke="#8cffb8" fill="url(#eqGrad)" strokeWidth={1.5} dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-[220px] text-sm font-mono" style={{ color: '#5e6a63' }}>暂无收益数据</div>
          )}
        </DepthCard>
      </div>

      {/* Network Flow + Data Sources */}
      <div className="grid grid-cols-1 xl:grid-cols-[1.2fr_1fr] gap-4">
        <DepthCard className="p-5">
          <div className="flex items-center justify-between mb-4">
            <span className="terminal-label">系统数据流</span>
            <span className="text-[9px] font-mono px-2 py-0.5 rounded" style={{ background: 'rgba(140,255,184,0.06)', color: '#8cffb8', border: '1px solid rgba(140,255,184,0.1)' }}>ACTIVE</span>
          </div>
          <NetworkFlow />
        </DepthCard>
        <DepthCard className="p-5">
          <div className="flex items-center justify-between mb-4">
            <span className="terminal-label">数据源</span>
            <span className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>6 个活跃源</span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {dataSources.map(s => (
              <div key={s.label} className="flex items-center justify-between p-3 rounded-lg" style={{ background: 'rgba(255,255,255,0.015)', border: '1px solid rgba(255,255,255,0.025)' }}>
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="w-1.5 h-1.5 rounded-full" style={{ background: s.color, boxShadow: `0 0 8px ${s.color}60` }} />
                    <span className="text-[12px] font-mono font-semibold">{s.label}</span>
                  </div>
                  <div className="text-[10px] font-mono mt-0.5 truncate" style={{ color: '#5e6a63' }}>{s.desc}</div>
                </div>
                <span className="text-[9px] font-mono px-1.5 py-0.5 shrink-0 rounded" style={{ color: s.color, border: `1px solid ${s.color}25`, background: `${s.color}08` }}>{s.status}</span>
              </div>
            ))}
          </div>
        </DepthCard>
      </div>

      {/* Trades + Positions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 card overflow-hidden" style={{ borderRadius: 12 }}>
          <div className="px-5 py-3 flex items-center justify-between" style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
            <span className="terminal-label">最近交易</span>
            <span className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>{orders?.length || 0} 笔</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                  {['币种', '方向', '时间', '盈亏'].map(h => (
                    <th key={h} className="px-5 py-2.5 text-[10px] font-mono font-medium tracking-wider uppercase text-left" style={{ color: '#5e6a63' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {orders && orders.length > 0 ? orders.slice(0, 8).map(order => (
                  <tr key={order.id} className="table-row" style={{ borderBottom: '1px solid rgba(255,255,255,0.02)' }}>
                    <td className="px-5 py-2.5 text-[13px] font-medium font-mono">{order.symbol}</td>
                    <td className="px-5 py-2.5">
                      <span className={cn('badge', order.side === 'BUY' ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                        {order.side}
                      </span>
                    </td>
                    <td className="px-5 py-2.5 text-[12px] font-mono" style={{ color: '#5e6a63' }}>
                      {new Date(order.timestamp).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                    </td>
                    <td className={cn('px-5 py-2.5 text-[13px] font-tabular font-medium text-right', getPnlColor(order.profit || 0))}>
                      {order.profit ? formatCurrency(order.profit) : '--'}
                    </td>
                  </tr>
                )) : (
                  <tr><td colSpan={4} className="px-5 py-10 text-center font-mono text-[12px]" style={{ color: '#5e6a63' }}>暂无交易记录</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        <DepthCard className="p-5">
          <span className="terminal-label block mb-3">当前持仓</span>
          <AnimatedList
            items={(positions ?? []).slice(0, 5)}
            getKey={(pos) => pos.id}
            renderItem={(pos) => (
              <div className="flex items-center justify-between p-3 rounded-lg" style={{ background: 'rgba(255,255,255,0.015)', border: '1px solid rgba(255,255,255,0.03)' }}>
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="text-[13px] font-medium font-mono">{pos.symbol}</span>
                    <span className={cn('badge text-[9px]', pos.side === 'long' ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                      {pos.side.toUpperCase()}
                    </span>
                  </div>
                  <div className="text-[11px] font-mono mt-0.5" style={{ color: '#5e6a63' }}>{pos.quantity} @ ${pos.avg_price.toLocaleString()}</div>
                </div>
                <div className={cn('text-[13px] font-tabular font-medium text-right', getPnlColor(pos.unrealized_pnl))}>
                  {formatCurrency(pos.unrealized_pnl)}
                </div>
              </div>
            )}
          />
          {(!positions || positions.length === 0) && (
            <div className="py-6 text-center text-[12px] font-mono" style={{ color: '#5e6a63' }}>暂无持仓</div>
          )}
        </DepthCard>
      </div>

      {/* Correlation Matrix */}
      {correlation && correlation.length > 0 && (
        <DepthCard className="p-6">
          <span className="terminal-label block mb-4">相关性矩阵</span>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {correlation.map(c => {
              const barColor = c.correlation > 0.85 ? '#ff6b6b' : c.correlation > 0.7 ? '#e8b86d' : '#8cffb8'
              const corrColor = c.correlation > 0.85 ? 'text-danger' : c.correlation > 0.7 ? 'text-warning' : 'text-success'
              return (
                <div key={c.id} className="flex items-center justify-between p-3 rounded-lg" style={{ background: 'rgba(255,255,255,0.015)', border: '1px solid rgba(255,255,255,0.03)' }}>
                  <div className="flex items-center gap-1.5 text-[13px] min-w-0 truncate font-mono">
                    <span className="font-medium">{c.symbol_a}</span>
                    <span style={{ color: '#344038' }}>/</span>
                    <span className="font-medium">{c.symbol_b}</span>
                  </div>
                  <div className="flex items-center gap-2.5 shrink-0 ml-3">
                    <div className="w-16 h-1 overflow-hidden rounded-full" style={{ background: 'rgba(255,255,255,0.03)' }}>
                      <div className="h-full rounded-full transition-all duration-700" style={{ width: `${c.correlation * 100}%`, background: barColor }} />
                    </div>
                    <span className={cn('text-[13px] font-tabular font-medium w-10 text-right', corrColor)}>
                      {c.correlation.toFixed(2)}
                    </span>
                  </div>
                </div>
              )
            })}
          </div>
        </DepthCard>
      )}
    </div>
  )
}
