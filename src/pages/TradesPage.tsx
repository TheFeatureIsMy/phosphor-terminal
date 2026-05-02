import { useState } from 'react'
import { Filter, Download } from 'lucide-react'
import { useOrders } from '@/hooks/use-dashboard'
import { cn, formatCurrency, getPnlColor } from '@/lib/utils'

export function TradesPage() {
  const { data: orders, isLoading } = useOrders(100)
  const [filterSide, setFilterSide] = useState<'all' | 'BUY' | 'SELL'>('all')
  const [filterSymbol, setFilterSymbol] = useState<string>('all')

  const symbols = [...new Set(orders?.map(o => o.symbol) || [])]
  const filtered = orders?.filter(o => {
    if (filterSide !== 'all' && o.side !== filterSide) return false
    if (filterSymbol !== 'all' && o.symbol !== filterSymbol) return false
    return true
  }) || []

  const totalPnl = filtered.reduce((sum, o) => sum + (o.profit || 0), 0)
  const winRate = filtered.length > 0 ? (filtered.filter(o => (o.profit || 0) > 0).length / filtered.length * 100) : 0

  if (isLoading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-text-muted text-sm animate-pulse">加载中...</div>
    </div>
  )

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold text-text-primary">交易记录</h1>
        <button className="btn-ghost flex items-center gap-1.5 px-3 py-1.5 text-sm">
          <Download className="w-3.5 h-3.5" /> 导出CSV
        </button>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <div className="card p-3.5">
          <span className="text-[11px] text-text-muted">总交易数</span>
          <div className="text-lg font-semibold font-tabular">{filtered.length}</div>
        </div>
        <div className="card p-3.5">
          <span className="text-[11px] text-text-muted">总盈亏</span>
          <div className={cn('text-lg font-semibold font-tabular', getPnlColor(totalPnl))}>{formatCurrency(totalPnl)}</div>
        </div>
        <div className="card p-3.5">
          <span className="text-[11px] text-text-muted">胜率</span>
          <div className="text-lg font-semibold font-tabular text-success">{winRate.toFixed(1)}%</div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Filter className="w-3.5 h-3.5 text-text-muted" />
        <select value={filterSide} onChange={e => setFilterSide(e.target.value as typeof filterSide)} className="px-2.5 py-1.5 text-sm">
          <option value="all">全部方向</option>
          <option value="BUY">买入</option>
          <option value="SELL">卖出</option>
        </select>
        <select value={filterSymbol} onChange={e => setFilterSymbol(e.target.value)} className="px-2.5 py-1.5 text-sm">
          <option value="all">全部币种</option>
          {symbols.map(s => <option key={s} value={s}>{s}</option>)}
        </select>
      </div>

      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
                {['时间', '币种', '方向', '数量', '价格', '成交价', '手续费', '盈亏', '状态'].map(h => (
                  <th key={h} className="px-4 py-2.5 text-[11px] text-text-muted font-medium tracking-wider uppercase text-left last:text-left">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map(order => (
                <tr key={order.id} className="table-row" style={{ borderBottom: '1px solid rgba(255,255,255,0.03)' }}>
                  <td className="px-4 py-2.5 text-[13px] text-text-secondary font-mono">
                    {new Date(order.timestamp).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })}
                  </td>
                  <td className="px-4 py-2.5 text-[13px] font-mono">{order.symbol}</td>
                  <td className="px-4 py-2.5">
                    <span className={cn('badge', order.side === 'BUY' ? 'bg-success-dim text-success' : 'bg-danger-dim text-danger')}>
                      {order.side}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-[13px] text-right font-mono">{order.quantity}</td>
                  <td className="px-4 py-2.5 text-[13px] text-right font-mono text-text-secondary">${order.price?.toLocaleString()}</td>
                  <td className="px-4 py-2.5 text-[13px] text-right font-mono">${order.filled_price?.toLocaleString()}</td>
                  <td className="px-4 py-2.5 text-[13px] text-right font-mono text-text-muted">${order.fee.toFixed(2)}</td>
                  <td className={cn('px-4 py-2.5 text-[13px] text-right font-tabular font-medium', getPnlColor(order.profit || 0))}>
                    {order.profit ? formatCurrency(order.profit) : '--'}
                  </td>
                  <td className="px-4 py-2.5">
                    <span className={cn('badge',
                      order.status === 'filled' ? 'bg-success-dim text-success' :
                      order.status === 'failed' ? 'bg-danger-dim text-danger' : 'bg-surface-active text-text-muted'
                    )}>
                      {order.status === 'filled' ? '已成交' : order.status === 'failed' ? '失败' : order.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
