import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { MTFGuardNodeData } from '../types'

export default function MTFGuardNode({ data, selected }: NodeProps) {
  const d = data as MTFGuardNodeData
  const fastTf = d.fastTimeframe ?? '5m'
  const slowTf = d.slowTimeframe ?? '1h'
  const structureType = d.structureType ?? 'order_block'
  const name = d.name ?? 'MTF Guard'
  const violationPolicy = d.violationPolicy ?? {
    temporaryViolation: 'hold',
    reclaimPending: 'reduce',
    confirmedReclaim: 'resume',
    confirmedBreak: 'exit',
  }

  return (
    <div className={`canvas-node ${selected ? 'selected' : ''}`}>
      <Handle type="target" position={Position.Left} id="guard-in" className="handle-in" />
      <div className="node-header mtf-guard">
        <span className="node-icon">🔀</span>
        <span className="node-title">{name}</span>
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">Timeframes</span>
          <span className="field-value">{fastTf} ↔ {slowTf}</span>
        </div>
        <div className="node-field">
          <span className="field-label">Structure</span>
          <span className="field-value">{structureType.replace(/_/g, ' ')}</span>
        </div>
        <div className="node-field">
          <span className="field-label">On Violation</span>
          <span className="field-value">{violationPolicy.temporaryViolation}</span>
        </div>
        <div className="node-field">
          <span className="field-label">On Break</span>
          <span className="field-value">{violationPolicy.confirmedBreak}</span>
        </div>
      </div>
      <Handle type="source" position={Position.Right} id="guard-out" className="handle-out" />
    </div>
  )
}
