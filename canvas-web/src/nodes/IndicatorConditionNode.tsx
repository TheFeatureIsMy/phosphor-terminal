import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'

export function IndicatorConditionNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const ruleType = data.ruleType as string
  const indicator = data.indicator as string
  const operator = data.operator as string
  const value = data.value as number | undefined
  const minValue = data.minValue as number | undefined
  const maxValue = data.maxValue as number | undefined
  const crossIndicator = data.crossIndicator as string | undefined
  const direction = data.direction as string | undefined
  const params = (data.params ?? {}) as Record<string, number>

  let conditionText: string
  if (ruleType === 'indicator_cross') {
    conditionText = `${indicator} ${direction ?? 'crosses'} ${crossIndicator ?? '?'}`
  } else if (['between', 'not_between'].includes(operator)) {
    conditionText = `${minValue ?? '?'} ~ ${maxValue ?? '?'}`
  } else {
    conditionText = `${operator ?? ''} ${value ?? '?'}`.trim()
  }

  const rows = [
    { k: '指标', v: indicator?.toUpperCase() ?? '未选择' },
    { k: '条件', v: conditionText },
  ]
  if (params.period != null) rows.push({ k: '周期', v: String(params.period) })

  return (
    <NodeShell
      type="indicatorCondition"
      title="指标条件"
      dotColor="var(--pa-node-condition)"
      rows={rows}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'condition' },
      ]}
    />
  )
}
