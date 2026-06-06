import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'

export function PositionSizingNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const hasError = errors.some(e => e.severity === 'error')
  const positionPct = data.positionPct as number
  return (
    <div className={`canvas-node node-sizing ${selected ? 'selected' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="node-header sizing">
        <span className="node-icon">📐</span>
        <span className="node-title">仓位管理</span>
        {errors.length > 0 && <span className="error-badge">{errors.length}</span>}
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">类型</span>
          <span className="field-value">固定百分比</span>
        </div>
        <div className="node-field">
          <span className="field-label">仓位</span>
          <span className="field-value">{(positionPct * 100).toFixed(1)}%</span>
        </div>
      </div>
      <Handle type="target" position={Position.Left} id="signal" className="handle-in" />
      <Handle type="source" position={Position.Right} id="sizing" className="handle-out" />
    </div>
  )
}
