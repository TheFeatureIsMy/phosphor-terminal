import { useEffect, useState } from 'react'
import { XAxis, YAxis, Tooltip, ResponsiveContainer, Area, AreaChart } from 'recharts'
import { TrendingUp, TrendingDown, Minus } from 'lucide-react'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

interface MarketSentiment {
  symbol: string
  score: number
  sentiment: string
  change_24h: number
}

interface TrendPoint {
  date: string
  score: number
  sentiment: string
}

interface SentimentData {
  market_overview: MarketSentiment[]
  fear_greed_index: number
  fear_greed_label: string
  trend: TrendPoint[]
}

const sentimentColors: Record<string, string> = {
  positive: '#8cffb8',
  negative: '#ff6b6b',
  neutral: '#e8b86d',
}

const sentimentIcons: Record<string, React.ElementType> = {
  positive: TrendingUp,
  negative: TrendingDown,
  neutral: Minus,
}

export function SentimentDashboard() {
  const [data, setData] = useState<SentimentData | null>(null)
  const [trendSymbol, setTrendSymbol] = useState('BTC/USDT')
  const [trendData, setTrendData] = useState<TrendPoint[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchSummary = async () => {
      try {
        const res = await fetch(`${API_BASE}/sentiment/summary`)
        if (res.ok) {
          const d = await res.json()
          setData(d)
        }
      } catch { /* fetch failed */ } finally {
        setLoading(false)
      }
    }
    fetchSummary()
  }, [])

  useEffect(() => {
    const fetchTrend = async () => {
      try {
        const res = await fetch(`${API_BASE}/sentiment/market/${encodeURIComponent(trendSymbol)}?days=14`)
        if (res.ok) {
          const d = await res.json()
          setTrendData(d.trend || [])
        }
      } catch { /* fetch failed */ }
    }
    fetchTrend()
  }, [trendSymbol])

  if (loading) {
    return (
      <div className="card p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-4 bg-white/5 rounded w-1/3" />
          <div className="h-48 bg-white/5 rounded" />
        </div>
      </div>
    )
  }

  const fearGreedColor = (data?.fear_greed_index ?? 50) > 60 ? '#8cffb8' : (data?.fear_greed_index ?? 50) < 40 ? '#ff6b6b' : '#e8b86d'

  return (
    <div className="space-y-5">
      {/* Fear & Greed Index */}
      <div className="card p-5">
        <div className="flex items-center justify-between mb-4">
          <span className="terminal-label">恐惧贪婪指数</span>
          <span className="text-[12px] font-mono" style={{ color: '#5e6a63' }}>
            {data?.fear_greed_label}
          </span>
        </div>
        <div className="flex items-center gap-4">
          <div className="relative w-24 h-24">
            <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
              <circle cx="50" cy="50" r="40" fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="8" />
              <circle
                cx="50" cy="50" r="40" fill="none"
                stroke={fearGreedColor}
                strokeWidth="8"
                strokeDasharray={`${(data?.fear_greed_index ?? 0) * 2.51} 251`}
                strokeLinecap="round"
              />
            </svg>
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-[20px] font-bold font-mono" style={{ color: fearGreedColor }}>
                {data?.fear_greed_index ?? '--'}
              </span>
            </div>
          </div>
          <div className="flex-1 space-y-2">
            {data?.market_overview?.map((item) => {
              const Icon = sentimentIcons[item.sentiment] || Minus
              return (
                <div key={item.symbol} className="flex items-center justify-between">
                  <span className="text-[12px] font-mono text-text-secondary">{item.symbol}</span>
                  <div className="flex items-center gap-2">
                    <Icon className="w-3 h-3" style={{ color: sentimentColors[item.sentiment] }} />
                    <span className="text-[12px] font-mono" style={{ color: sentimentColors[item.sentiment] }}>
                      {(item.score * 100).toFixed(0)}%
                    </span>
                    <span className="text-[10px] font-mono" style={{ color: item.change_24h >= 0 ? '#8cffb8' : '#ff6b6b' }}>
                      {item.change_24h >= 0 ? '+' : ''}{(item.change_24h * 100).toFixed(1)}%
                    </span>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>

      {/* Sentiment Trend */}
      <div className="card p-5">
        <div className="flex items-center justify-between mb-4">
          <span className="terminal-label">情绪趋势</span>
          <select
            value={trendSymbol}
            onChange={(e) => setTrendSymbol(e.target.value)}
            className="text-[11px] font-mono px-2 py-1"
            style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)' }}
          >
            {data?.market_overview?.map((m) => (
              <option key={m.symbol} value={m.symbol}>{m.symbol}</option>
            ))}
          </select>
        </div>

        <ResponsiveContainer width="100%" height={200}>
          <AreaChart data={trendData}>
            <defs>
              <linearGradient id="sentGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#8cffb8" stopOpacity={0.3} />
                <stop offset="100%" stopColor="#8cffb8" stopOpacity={0} />
              </linearGradient>
            </defs>
            <XAxis
              dataKey="date"
              tick={{ fontSize: 10, fill: '#5e6a63' }}
              tickFormatter={(v) => v.slice(5)}
            />
            <YAxis domain={[0, 1]} tick={{ fontSize: 10, fill: '#5e6a63' }} />
            <Tooltip
              contentStyle={{
                background: '#1a1a1a',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: '2px',
                fontSize: '12px',
                fontFamily: 'monospace',
              }}
              formatter={(v) => [`${(Number(v) * 100).toFixed(1)}%`, '情绪分数']}
              labelFormatter={(v) => `日期: ${v}`}
            />
            <Area
              type="monotone"
              dataKey="score"
              stroke="#8cffb8"
              strokeWidth={2}
              fill="url(#sentGrad)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Sentiment Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {data?.market_overview?.map((item) => {
          const color = sentimentColors[item.sentiment]
          const Icon = sentimentIcons[item.sentiment] || Minus
          return (
            <div key={item.symbol} className="card px-4 py-3">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-6 h-6 flex items-center justify-center" style={{ background: `${color}15`, borderRadius: '2px' }}>
                  <Icon className="w-3 h-3" style={{ color }} />
                </div>
                <span className="text-[12px] font-mono font-medium text-text-primary">{item.symbol}</span>
              </div>
              <div className="text-[18px] font-bold font-tabular" style={{ color }}>
                {(item.score * 100).toFixed(0)}%
              </div>
              <div className="text-[10px] font-mono text-text-muted mt-0.5">
                {item.sentiment === 'positive' ? '看涨' : item.sentiment === 'negative' ? '看跌' : '中性'}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
