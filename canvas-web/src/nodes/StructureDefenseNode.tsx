import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { StructureDefenseData } from '../types'

export default function StructureDefenseNode({ data, selected }: NodeProps) {
  const d = data as StructureDefenseData
  const structures = d.structures ?? ['liquidity_pool', 'fvg']
  const minScore = d.minStructureScore ?? 70

  return (
    <div className={`node node-structure ${selected ? 'selected' : ''}`}>
      <Handle type="target" position={Position.Left} id="signal" />
      <div className="node-header">
        <span className="node-icon">🛡</span>
        <span className="node-title">Structure Defense</span>
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">Structures</span>
          <span className="field-value">{structures.join(', ')}</span>
        </div>
        <div className="node-field">
          <span className="field-label">Min Score</span>
          <span className="field-value">{minScore}</span>
        </div>
      </div>
      <Handle type="source" position={Position.Right} id="defense" />
    </div>
  )
}
