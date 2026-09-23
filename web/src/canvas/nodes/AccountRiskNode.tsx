import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError, AccountRiskData } from '../types'
import { NodeShell } from './NodeShell'

export default function AccountRiskNode({ data, selected }: NodeProps) {
  const d = data as AccountRiskData & { validationErrors?: DSLError[] }
  const errors = d.validationErrors ?? []
  const invalid = errors.some(e => e.severity === 'error')
  const maxDaily = d.maxDailyLoss ?? 0.03
  const maxWeekly = d.maxWeeklyLoss ?? 0.08
  const maxConsec = d.maxConsecutiveLosses ?? 4

  return (
    <NodeShell
      type="accountRisk"
      title="账户风控防火墙"
      dotColor="var(--pa-node-account)"
      rows={[
        { k: '日亏损上限', v: `${(maxDaily * 100).toFixed(1)}%` },
        { k: '周亏损上限', v: `${(maxWeekly * 100).toFixed(1)}%` },
        { k: '最大连亏', v: String(maxConsec) },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'source', position: Position.Right, id: 'accountRisk' },
      ]}
    />
  )
}
