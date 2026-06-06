import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'

export function RiskPolicyNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const hasError = errors.some(e => e.severity === 'error')
  const stoploss = data.stoploss as number
  const maxOpenTrades = data.maxOpenTrades as number
  const trailingStop = data.trailingStop as boolean | undefined
  return (
    <div className={`canvas-node node-risk ${selected ? 'selected' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="node-header risk">
        <span className="node-icon">🛡️</span>
        <span className="node-title">风控策略</span>
        {errors.length > 0 && <span className="error-badge">{errors.length}</span>}
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">止损</span>
          <span className="field-value">{(stoploss * 100).toFixed(1)}%</span>
        </div>
        <div className="node-field">
          <span className="field-label">最大持仓</span>
          <span className="field-value">{maxOpenTrades}</span>
        </div>
        {trailingStop && (
          <div className="node-field">
            <span className="field-label">追踪止损</span>
            <span className="field-value">开启</span>
          </div>
        )}
      </div>
      <Handle type="target" position={Position.Left} id="signal" className="handle-in" />
      <Handle type="source" position={Position.Right} id="risk" className="handle-out" />
    </div>
  )
}
