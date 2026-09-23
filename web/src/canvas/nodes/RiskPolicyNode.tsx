import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'
import { NodeNumber, NodeToggle } from './EditableControls'

export function RiskPolicyNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const stoploss = (data.stoploss as number) ?? -0.05
  const maxOpenTrades = (data.maxOpenTrades as number) ?? 3
  const trailingStop = (data.trailingStop as boolean) ?? false

  const set = (patch: Record<string, unknown>) => updateNodeData(id, patch)

  return (
    <NodeShell
      type="riskPolicy"
      title="风控策略"
      dotColor="var(--pa-node-risk)"
      rows={[
        {
          k: '止损%',
          edit: true,
          v: (
            <NodeNumber
              value={+(stoploss * 100).toFixed(1)}
              step={0.5}
              ariaLabel="止损百分比"
              onChange={v => set({ stoploss: v / 100 })}
            />
          ),
        },
        {
          k: '最大持仓',
          edit: true,
          v: (
            <NodeNumber
              value={maxOpenTrades}
              step={1}
              ariaLabel="最大持仓数"
              onChange={v => set({ maxOpenTrades: Math.max(1, Math.round(v)) })}
            />
          ),
        },
        {
          k: '追踪止损',
          edit: true,
          v: (
            <NodeToggle
              checked={trailingStop}
              ariaLabel="追踪止损"
              onChange={v => set({ trailingStop: v })}
            />
          ),
        },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'risk' },
      ]}
    />
  )
}