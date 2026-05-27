import { useState } from 'react'
import { Filter, Download } from 'lucide-react'
import { useOrders } from '@/hooks/use-dashboard'
import { cn, formatCurrency, getPnlColor } from '@/lib/utils'
import { CardSkeleton, TableSkeleton } from '@/components/ui/Skeleton'

interface TradesTableProps {
  /** Filter by strategy ID. If omitted, shows all orders. */
  strategyId?: number
  /** Max orders to fetch */
  limit?: number
  /** Show summary stats above the table */
  showStats?: boolean
}

export function TradesTable({ strategyId, limit = 100, showStats = true }: TradesTableProps) {
  const { data: allOrders, isLoading } = useOrders(limit)
  const [filterSide, setFilterSide] = useState<'all' | 'BUY' | 'SELL'>('all')

  const orders = allOrders?.filter(o => strategyId ? o.strategy_id === strategyId : true) || []
  const filtered = orders.filter(o => filterSide === 'all' || o.side === filterSide)

  const totalPnl = filtered.reduce((sum, o) => sum + (o.profit || 0), 0)
  const winRate = filtered.length > 0 ? (filtered.filter(o => (o.profit || 0) > 0).length / filtered.length * 100) : 0

  if (isLoading) {
    return (
      <div className="space-y-5">
        {showStats && (
          <div className="grid grid-cols-3 gap-4">
            <CardSkeleton />
            <CardSkeleton />
            <CardSkeleton />
          </div>
        )}
        <TableSkeleton rows={8} cols={6} />
      </div>
    )
  }

  return (
    <div className="space-y-5">
      {showStats && (
        <div className="grid grid-cols-3 gap-4">
          <div className="card p-5">
            <span className="terminal-label block mb-2">总交易数</span>
            <div className="text-2xl font-bold font-tabular">{filtered.length}</div>
          </div>
          <div className="card p-5">
            <span className="terminal-label block mb-2">总盈亏</span>
            <div className={cn('text-2xl font-bold font-tabular', getPnlColor(totalPnl))}>{formatCurrency(totalPnl)}</div>
          </div>
          <div className="card p-5">
            <span className="terminal-label block mb-2">胜率</span>
            <div className="text-2xl font-bold font-tabular text-success">{winRate.toFixed(1)}%</div>
          </div>
        </div>
      )}

      <div className="flex items-center gap-2">
        <Filter className="w-4 h-4 text-text-muted" />
        <div className="flex gap-1 p-1" style={{ background: 'rgba(255,255,255,0.03)', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.06)' }}>
          {(['all', 'BUY', 'SELL'] as const).map(side => (
            <button
              key={side}
              onClick={() => setFilterSide(side)}
              className={cn(
                'px-3.5 py-1.5 text-[12px] transition-colors',
                filterSide === side ? 'bg-white/[0.08] text-text-primary' : 'text-text-muted hover:text-text-secondary'
              )}
              style={{ borderRadius: '8px' }}
            >
              {side === 'all' ? '全部' : side === 'BUY' ? '买入' : '卖出'}
            </button>
          ))}
        </div>
        <button className="btn-ghost flex items-center gap-1.5 px-3.5 py-1.5 text-[12px] ml-auto">
          <Download className="w-3 h-3" /> 导出CSV
        </button>
      </div>

      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
                {['时间', '币种', '方向', '数量', '价格', '成交价', '手续费', '盈亏', '状态'].map(h => (
                  <th key={h} className="px-4 py-3 text-[11px] text-text-muted font-semibold tracking-wider uppercase text-left">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map(order => (
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
                  <td className="px-4 py-3 text-[13px] text-right text-text-secondary">${order.price?.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[13px] text-right">${order.filled_price?.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[13px] text-right text-text-muted">${order.fee.toFixed(2)}</td>
                  <td className={cn('px-4 py-3 text-[13px] text-right font-tabular font-medium', getPnlColor(order.profit || 0))}>
                    {order.profit ? formatCurrency(order.profit) : '--'}
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn('badge',
                      order.status === 'filled' ? 'bg-success-dim text-success' :
                      order.status === 'failed' ? 'bg-danger-dim text-danger' : 'bg-surface-active text-text-muted'
                    )}>
                      {order.status === 'filled' ? '已成交' : order.status === 'failed' ? '失败' : order.status}
                    </span>
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={9} className="px-4 py-8 text-center text-[14px] text-text-muted">暂无交易记录</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
