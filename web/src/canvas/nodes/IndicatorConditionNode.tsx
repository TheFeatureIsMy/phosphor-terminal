import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'
import { NodeNumber, NodeSelect } from './EditableControls'

const INDICATORS = ['rsi', 'macd', 'ema', 'sma', 'bollinger', 'atr', 'stochastic', 'adx', 'obv', 'vwap', 'roc', 'cci', 'willr', 'momentum']
const OPERATORS = ['<', '>', '<=', '>=', '==', '!=', 'between', 'not_between']

export function IndicatorConditionNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const ruleType = (data.ruleType as string) ?? 'indicator_threshold'
  const indicator = (data.indicator as string) ?? 'rsi'
  const operator = (data.operator as string) ?? '<'
  const value = data.value as number | undefined
  const minValue = data.minValue as number | undefined
  const maxValue = data.maxValue as number | undefined
  const params = (data.params ?? {}) as Record<string, number>
  const period = params.period ?? 14

  const set = (patch: Record<string, unknown>) => updateNodeData(id, patch)

  const rows = [
    {
      k: '指标',
      edit: true,
      v: (
        <NodeSelect
          value={indicator}
          ariaLabel="指标"
          options={INDICATORS.map(i => ({ value: i, label: i.toUpperCase() }))}
          onChange={v => set({ indicator: v })}
        />
      ),
    },
    {
      k: '操作',
      edit: true,
      v: (
        <NodeSelect
          value={operator}
          ariaLabel="操作符"
          options={OPERATORS.map(o => ({ value: o, label: o }))}
          onChange={v => set({ operator: v })}
        />
      ),
    },
  ]

  if (['between', 'not_between'].includes(operator)) {
    rows.push({
      k: '最小',
      edit: true,
      v: <NodeNumber value={minValue ?? 0} ariaLabel="最小值" onChange={v => set({ minValue: v })} />,
    })
    rows.push({
      k: '最大',
      edit: true,
      v: <NodeNumber value={maxValue ?? 0} ariaLabel="最大值" onChange={v => set({ maxValue: v })} />,
    })
  } else {
    rows.push({
      k: '阈值',
      edit: true,
      v: <NodeNumber value={value ?? 0} ariaLabel="阈值" onChange={v => set({ value: v })} />,
    })
  }

  rows.push({
    k: '周期',
    edit: true,
    v: <NodeNumber value={period} ariaLabel="周期" onChange={v => set({ params: { ...params, period: v } })} />,
  })

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