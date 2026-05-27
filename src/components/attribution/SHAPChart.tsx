import { useEffect, useState } from 'react'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

interface FeatureImportance {
  features: string[]
  importances: number[]
}

interface DecisionPathItem {
  feature: string
  value: number
  contribution: number
  cumulative: number
  passed: boolean
}

interface Props {
  strategyId: number
}

export function SHAPChart({ strategyId }: Props) {
  const [importance, setImportance] = useState<FeatureImportance | null>(null)
  const [decisionPath, setDecisionPath] = useState<DecisionPathItem[]>([])
  const [decision, setDecision] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await fetch(`${API_BASE}/attribution/summary/${strategyId}`)
        if (res.ok) {
          const data = await res.json()
          setImportance(data.feature_importance)
          setDecisionPath(data.decision_path?.path || [])
          setDecision(data.decision_path?.decision || 'hold')
        }
      } catch { /* fetch failed */ } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [strategyId])

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

  const chartData = importance
    ? importance.features.slice(0, 8).map((f, i) => ({
        name: f,
        value: importance.importances[i],
      }))
    : []

  const decisionColor = decision === 'buy' ? '#00ff9d' : decision === 'sell' ? '#ff3b3b' : '#ff9500'

  return (
    <div className="space-y-5">
      {/* Feature Importance */}
      <div className="card p-5">
        <div className="flex items-center justify-between mb-4">
          <div>
            <span className="terminal-label">特征重要性</span>
            <p className="text-[11px] font-mono text-text-muted mt-0.5">SHAP 归因分析</p>
          </div>
          <div
            className="px-3 py-1.5 text-[12px] font-mono font-bold uppercase"
            style={{
              background: `${decisionColor}15`,
              color: decisionColor,
              border: `1px solid ${decisionColor}30`,
              borderRadius: '2px',
            }}
          >
            {decision}
          </div>
        </div>

        <ResponsiveContainer width="100%" height={240}>
          <BarChart data={chartData} layout="vertical" margin={{ left: 80 }}>
            <XAxis type="number" tick={{ fontSize: 10, fill: '#555' }} />
            <YAxis type="category" dataKey="name" tick={{ fontSize: 11, fill: '#888', fontFamily: 'monospace' }} width={75} />
            <Tooltip
              contentStyle={{
                background: '#1a1a1a',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: '2px',
                fontSize: '12px',
                fontFamily: 'monospace',
              }}
              formatter={(v: number) => [`${(v * 100).toFixed(1)}%`, '重要性']}
            />
            <Bar dataKey="value" radius={[0, 2, 2, 0]}>
              {chartData.map((_, i) => (
                <Cell key={i} fill={i < 3 ? '#00ff9d' : i < 5 ? '#00ff9d80' : '#00ff9d40'} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Decision Path */}
      <div className="card p-5">
        <span className="terminal-label block mb-4">决策路径</span>
        <div className="space-y-2">
          {decisionPath.slice(0, 6).map((item, i) => (
            <div key={item.feature} className="flex items-center gap-3">
              <div className="w-6 h-6 flex items-center justify-center text-[10px] font-mono font-bold shrink-0"
                style={{
                  background: item.passed ? 'rgba(0,255,157,0.1)' : 'rgba(255,59,59,0.1)',
                  color: item.passed ? '#00ff9d' : '#ff3b3b',
                  borderRadius: '2px',
                }}>
                {i + 1}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between">
                  <span className="text-[12px] font-mono text-text-primary">{item.feature}</span>
                  <span className="text-[11px] font-mono" style={{ color: item.contribution > 0 ? '#00ff9d' : '#ff3b3b' }}>
                    {item.contribution > 0 ? '+' : ''}{(item.contribution * 100).toFixed(1)}%
                  </span>
                </div>
                <div className="mt-1 h-1 rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.06)' }}>
                  <div
                    className="h-full rounded-full transition-all"
                    style={{
                      width: `${Math.min(100, Math.abs(item.contribution) * 500)}%`,
                      background: item.contribution > 0 ? '#00ff9d' : '#ff3b3b',
                    }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
