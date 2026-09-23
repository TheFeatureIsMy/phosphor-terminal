import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { FILTER_TYPES } from '../constants'
import { NodeShell } from './NodeShell'
import { NodeNumber, NodeSelect } from './EditableControls'

export function FilterNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const ruleType = (data.ruleType as string) ?? 'volume_filter'
  const maxScore = data.maxScore as number | undefined
  const candles = data.candles as number | undefined

  const set = (patch: Record<string, unknown>) => updateNodeData(id, patch)

  const rows: { k: string; v: React.ReactNode; edit?: boolean }[] = [
    {
      k: '类型',
      edit: true,
      v: (
        <NodeSelect
          value={ruleType}
          ariaLabel="过滤类型"
          options={FILTER_TYPES.map(f => ({ value: f.value, label: f.label }))}
          onChange={v => set({ ruleType: v })}
        />
      ),
    },
  ]
  if (maxScore != null) {
    rows.push({
      k: '最大评分',
      edit: true,
      v: <NodeNumber value={maxScore} step={0.1} ariaLabel="最大评分" onChange={v => set({ maxScore: v })} />,
    })
  }
  if (candles != null) {
    rows.push({
      k: '冷却K线',
      edit: true,
      v: <NodeNumber value={candles} step={1} ariaLabel="冷却K线数" onChange={v => set({ candles: Math.max(0, Math.round(v)) })} />,
    })
  }

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