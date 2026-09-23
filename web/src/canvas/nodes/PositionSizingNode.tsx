import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'
import { NodeNumber } from './EditableControls'

export function PositionSizingNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const positionPct = (data.positionPct as number) ?? 0.05

  const set = (patch: Record<string, unknown>) => updateNodeData(id, patch)

  return (
    <NodeShell
      type="positionSizing"
      title="仓位管理"
      dotColor="var(--pa-node-sizing)"
      rows={[
        { k: '类型', v: '固定百分比' },
        {
          k: '仓位%',
          edit: true,
          v: (
            <NodeNumber
              value={+(positionPct * 100).toFixed(1)}
              step={0.5}
              ariaLabel="仓位百分比"
              onChange={v => set({ positionPct: v / 100 })}
            />
          ),
        },
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