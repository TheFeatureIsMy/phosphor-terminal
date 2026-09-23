import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'
import { NodeSelect, NodeText } from './EditableControls'

const TIMEFRAMES = ['1m', '5m', '15m', '1h', '4h', '1d', '1w']

export function SignalInputNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const timeframe = (data.timeframe as string) ?? '1d'
  const symbols = (data.symbols as string[]) ?? []

  const set = (patch: Record<string, unknown>) => updateNodeData(id, patch)

  return (
    <NodeShell
      type="signalInput"
      title="信号输入"
      dotColor="var(--pa-node-signal)"
      rows={[
        {
          k: '周期',
          edit: true,
          v: (
            <NodeSelect
              value={timeframe}
              ariaLabel="周期"
              options={TIMEFRAMES.map(t => ({ value: t, label: t }))}
              onChange={v => set({ timeframe: v })}
            />
          ),
        },
        {
          k: '标的',
          edit: true,
          v: (
            <NodeText
              value={symbols.join(',')}
              placeholder="BTC/USDT"
              ariaLabel="标的"
              onChange={v => set({ symbols: v.split(',').map(s => s.trim()).filter(Boolean) })}
            />
          ),
        },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[{ type: 'source', position: Position.Right, id: 'signal' }]}
    />
  )
}