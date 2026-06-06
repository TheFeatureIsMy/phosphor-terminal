import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { FILTER_TYPES } from '../constants'

export function FilterNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const hasError = errors.some(e => e.severity === 'error')
  const ruleType = data.ruleType as string
  const label = FILTER_TYPES.find(f => f.value === ruleType)?.label ?? ruleType
  return (
    <div className={`canvas-node node-filter ${selected ? 'selected' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="node-header filter">
        <span className="node-icon">🔍</span>
        <span className="node-title">过滤器</span>
        {errors.length > 0 && <span className="error-badge">{errors.length}</span>}
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">类型</span>
          <span className="field-value">{label}</span>
        </div>
        {data.value != null && (
          <div className="node-field">
            <span className="field-label">阈值</span>
            <span className="field-value">{(data.operator as string) ?? ''} {data.value as number}</span>
          </div>
        )}
        {data.maxScore != null && (
          <div className="node-field">
            <span className="field-label">最大评分</span>
            <span className="field-value">{data.maxScore as number}</span>
          </div>
        )}
        {data.candles != null && (
          <div className="node-field">
            <span className="field-label">冷却K线</span>
            <span className="field-value">{data.candles as number}</span>
          </div>
        )}
      </div>
      <Handle type="target" position={Position.Left} id="signal" className="handle-in" />
      <Handle type="source" position={Position.Right} id="filtered" className="handle-out" />
    </div>
  )
}
