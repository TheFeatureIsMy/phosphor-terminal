import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'

export function SignalInputNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const timeframe = data.timeframe as string
  const symbols = (data.symbols as string[]) ?? []

  return (
    <NodeShell
      type="signalInput"
      title="信号输入"
      dotColor="var(--pa-node-signal)"
      rows={[
        { k: '周期', v: timeframe ?? '—' },
        { k: '标的', v: symbols.join(', ') || '—' },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[{ type: 'source', position: Position.Right, id: 'signal' }]}
    />
  )
}
