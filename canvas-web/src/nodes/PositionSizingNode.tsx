import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'

export function PositionSizingNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const positionPct = (data.positionPct as number) ?? 0

  return (
    <NodeShell
      type="positionSizing"
      title="仓位管理"
      dotColor="var(--pa-node-sizing)"
      rows={[
        { k: '类型', v: '固定百分比' },
        { k: '仓位', v: `${(positionPct * 100).toFixed(1)}%` },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'sizing' },
      ]}
    />
  )
}
