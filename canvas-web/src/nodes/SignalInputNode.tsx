import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'

export function SignalInputNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const hasError = errors.some(e => e.severity === 'error')
  const timeframe = data.timeframe as string
  const symbols = (data.symbols as string[]) ?? []
  return (
    <div className={`canvas-node node-signal ${selected ? 'selected' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="node-header signal">
        <span className="node-icon">📡</span>
        <span className="node-title">信号输入</span>
        {errors.length > 0 && <span className="error-badge">{errors.length}</span>}
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">周期</span>
          <span className="field-value">{timeframe}</span>
        </div>
        <div className="node-field">
          <span className="field-label">标的</span>
          <span className="field-value">{symbols.join(', ')}</span>
        </div>
      </div>
      <Handle type="source" position={Position.Right} id="signal" className="handle-out" />
    </div>
  )
}
