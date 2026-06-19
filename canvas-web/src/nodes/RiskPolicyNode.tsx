import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'

export function RiskPolicyNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const stoploss = (data.stoploss as number) ?? 0
  const maxOpenTrades = data.maxOpenTrades as number
  const trailingStop = data.trailingStop as boolean | undefined

  const rows = [
    { k: '止损', v: `${(stoploss * 100).toFixed(1)}%` },
    { k: '最大持仓', v: String(maxOpenTrades ?? '—') },
  ]
  if (trailingStop) rows.push({ k: '追踪止损', v: '开启' })

  return (
    <NodeShell
      type="riskPolicy"
      title="风控策略"
      dotColor="var(--pa-node-risk)"
      rows={rows}
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
