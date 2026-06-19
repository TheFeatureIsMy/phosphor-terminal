import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { FILTER_TYPES } from '../constants'
import { NodeShell } from './NodeShell'

export function FilterNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const ruleType = data.ruleType as string
  const label = FILTER_TYPES.find(f => f.value === ruleType)?.label ?? ruleType

  const rows: { k: string; v: string }[] = [{ k: '类型', v: label ?? '—' }]
  if (data.value != null) {
    rows.push({ k: '阈值', v: `${(data.operator as string) ?? ''} ${data.value as number}`.trim() })
  }
  if (data.maxScore != null) rows.push({ k: '最大评分', v: String(data.maxScore as number) })
  if (data.candles != null) rows.push({ k: '冷却K线', v: String(data.candles as number) })

  return (
    <NodeShell
      type="filter"
      title="过滤器"
      dotColor="var(--pa-node-filter)"
      rows={rows}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'filtered' },
      ]}
    />
  )
}
