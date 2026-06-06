import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { AccountRiskData } from '../types'

export default function AccountRiskNode({ data, selected }: NodeProps) {
  const d = data as AccountRiskData
  const maxDaily = d.maxDailyLoss ?? 0.03
  const maxWeekly = d.maxWeeklyLoss ?? 0.08
  const maxConsec = d.maxConsecutiveLosses ?? 4

  return (
    <div className={`node node-risk-firewall ${selected ? 'selected' : ''}`}>
      <div className="node-header">
        <span className="node-icon">🔥</span>
        <span className="node-title">Account Risk Firewall</span>
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">Max Daily Loss</span>
          <span className="field-value">{(maxDaily * 100).toFixed(1)}%</span>
        </div>
        <div className="node-field">
          <span className="field-label">Max Weekly Loss</span>
          <span className="field-value">{(maxWeekly * 100).toFixed(1)}%</span>
        </div>
        <div className="node-field">
          <span className="field-label">Max Consecutive</span>
          <span className="field-value">{maxConsec}</span>
        </div>
      </div>
      <Handle type="source" position={Position.Right} id="accountRisk" />
    </div>
  )
}
