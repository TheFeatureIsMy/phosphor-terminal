import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError, StructureDefenseData } from '../types'
import { NodeShell } from './NodeShell'

export default function StructureDefenseNode({ data, selected }: NodeProps) {
  const d = data as StructureDefenseData & { validationErrors?: DSLError[] }
  const errors = d.validationErrors ?? []
  const invalid = errors.some(e => e.severity === 'error')
  const structures = d.structures ?? ['liquidity_pool', 'fvg']
  const minScore = d.minStructureScore ?? 70

  return (
    <NodeShell
      type="structureDefense"
      title="Structure Defense"
      dotColor="var(--pa-node-structure)"
      rows={[
        { k: 'structures', v: structures.join(', ') },
        { k: 'min score', v: String(minScore) },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'defense' },
      ]}
    />
  )
}
