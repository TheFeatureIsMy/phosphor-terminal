import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'

export function ExecutionOutputNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')

  return (
    <NodeShell
      type="executionOutput"
      title="执行输出"
      dotColor="var(--pa-node-output)"
      rows={[
        { k: '入场', v: (data.entryLogic as string) ?? '—' },
        { k: '出场', v: (data.exitLogic as string) ?? '—' },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'entryConditions', style: { top: '30%' } },
        { type: 'target', position: Position.Left, id: 'exitConditions', style: { top: '50%' } },
        { type: 'target', position: Position.Left, id: 'filters', style: { top: '70%' } },
        { type: 'target', position: Position.Bottom, id: 'sizing', style: { left: '35%' } },
        { type: 'target', position: Position.Bottom, id: 'risk', style: { left: '65%' } },
      ]}
    />
  )
}
