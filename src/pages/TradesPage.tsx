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

  if (isLoading) return <div className="animate-pulse text-text-muted">Loading trades...</div>

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">交易记录</h1>
        <button className="flex items-center gap-2 px-3 py-1.5 text-sm text-text-secondary hover:text-text-primary bg-surface rounded-lg border border-border transition-colors">
          <Download className="w-4 h-4" /> 导出CSV
        </button>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-surface rounded-xl p-4 border border-border">
          <span className="text-xs text-text-muted">总交易数</span>
          <div className="text-xl font-bold font-tabular">{filtered.length}</div>
        </div>
        <div className="bg-surface rounded-xl p-4 border border-border">
          <span className="text-xs text-text-muted">总盈亏</span>
          <div className={cn('text-xl font-bold font-tabular', getPnlColor(totalPnl))}>{formatCurrency(totalPnl)}</div>
        </div>
        <div className="bg-surface rounded-xl p-4 border border-border">
          <span className="text-xs text-text-muted">胜率</span>
          <div className="text-xl font-bold font-tabular text-success">{winRate.toFixed(1)}%</div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3">
        <Filter className="w-4 h-4 text-text-muted" />
        <select value={filterSide} onChange={e => setFilterSide(e.target.value as typeof filterSide)}
          className="px-3 py-1.5 bg-surface border border-border rounded-lg text-sm text-text-primary focus:outline-none focus:border-primary">
          <option value="all">全部方向</option>
          <option value="BUY">买入</option>
          <option value="SELL">卖出</option>
        </select>
        <select value={filterSymbol} onChange={e => setFilterSymbol(e.target.value)}
          className="px-3 py-1.5 bg-surface border border-border rounded-lg text-sm text-text-primary focus:outline-none focus:border-primary">
          <option value="all">全部币种</option>
          {symbols.map(s => <option key={s} value={s}>{s}</option>)}
        </select>
      </div>

      {/* Table */}
      <div className="bg-surface rounded-xl border border-border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border">
                <th className="text-left px-4 py-3 text-xs text-text-muted font-medium">时间</th>
                <th className="text-left px-4 py-3 text-xs text-text-muted font-medium">币种</th>
                <th className="text-left px-4 py-3 text-xs text-text-muted font-medium">方向</th>
                <th className="text-right px-4 py-3 text-xs text-text-muted font-medium">数量</th>
                <th className="text-right px-4 py-3 text-xs text-text-muted font-medium">价格</th>
                <th className="text-right px-4 py-3 text-xs text-text-muted font-medium">成交价</th>
                <th className="text-right px-4 py-3 text-xs text-text-muted font-medium">手续费</th>
                <th className="text-right px-4 py-3 text-xs text-text-muted font-medium">盈亏</th>
                <th className="text-left px-4 py-3 text-xs text-text-muted font-medium">状态</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(order => (
                <tr key={order.id} className="border-b border-border/50 hover:bg-surface-hover transition-colors">
                  <td className="px-4 py-3 text-sm text-text-secondary font-mono">
                    {new Date(order.timestamp).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })}
                  </td>
                  <td className="px-4 py-3 text-sm font-medium">{order.symbol}</td>
                  <td className="px-4 py-3">
                    <span className={cn(
                      'px-2 py-0.5 rounded text-xs font-medium',
                      order.side === 'BUY' ? 'bg-profit/15 text-profit' : 'bg-loss/15 text-loss'
                    )}>
                      {order.side}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-right font-tabular">{order.quantity}</td>
                  <td className="px-4 py-3 text-sm text-right font-tabular text-text-secondary">${order.price?.toLocaleString()}</td>
                  <td className="px-4 py-3 text-sm text-right font-tabular">${order.filled_price?.toLocaleString()}</td>
                  <td className="px-4 py-3 text-sm text-right font-tabular text-text-muted">${order.fee.toFixed(2)}</td>
                  <td className={cn('px-4 py-3 text-sm text-right font-tabular font-medium', getPnlColor(order.profit || 0))}>
                    {order.profit ? formatCurrency(order.profit) : '--'}
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn(
                      'px-2 py-0.5 rounded text-xs',
                      order.status === 'filled' ? 'bg-success/15 text-success' :
                      order.status === 'failed' ? 'bg-danger/15 text-danger' : 'bg-text-muted/15 text-text-muted'
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
