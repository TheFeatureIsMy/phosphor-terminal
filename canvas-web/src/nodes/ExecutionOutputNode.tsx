import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'

export function ExecutionOutputNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const hasError = errors.some(e => e.severity === 'error')
  return (
    <div className={`canvas-node node-output ${selected ? 'selected' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="node-header output">
        <span className="node-icon">🚀</span>
        <span className="node-title">执行输出</span>
        {errors.length > 0 && <span className="error-badge">{errors.length}</span>}
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">入场逻辑</span>
          <span className="field-value">{data.entryLogic as string}</span>
        </div>
        <div className="node-field">
          <span className="field-label">出场逻辑</span>
          <span className="field-value">{data.exitLogic as string}</span>
        </div>
      </div>
      <Handle type="target" position={Position.Left} id="entryConditions" className="handle-in handle-entry" style={{ top: '30%' }} />
      <Handle type="target" position={Position.Left} id="exitConditions" className="handle-in handle-exit" style={{ top: '50%' }} />
      <Handle type="target" position={Position.Left} id="filters" className="handle-in handle-filter" style={{ top: '70%' }} />
      <Handle type="target" position={Position.Bottom} id="sizing" className="handle-in" style={{ left: '35%' }} />
      <Handle type="target" position={Position.Bottom} id="risk" className="handle-in" style={{ left: '65%' }} />
    </div>
  )
}
