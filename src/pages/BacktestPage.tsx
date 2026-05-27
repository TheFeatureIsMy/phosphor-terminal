import { useState } from 'react'
import { Play } from 'lucide-react'
import { useStrategies } from '@/hooks/use-strategies'
import { useQuery } from '@tanstack/react-query'
import { runBacktest } from '@/api/dashboard'
import { BacktestResults } from '@/components/shared/BacktestResults'
import { PageHeader } from '@/components/ui/PageHeader'

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
      <PageHeader title="回测中心" />

      <div className="card p-4">
        <span className="terminal-label">回测配置</span>
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

      {backtest && <BacktestResults backtest={backtest} />}
    </div>
  )
}
