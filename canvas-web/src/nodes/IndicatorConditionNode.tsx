import { Handle, Position, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'

export function IndicatorConditionNode({ data, selected }: NodeProps) {
  const errors = (data.validationErrors ?? []) as DSLError[]
  const hasError = errors.some(e => e.severity === 'error')
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
    conditionText = `${operator} ${value ?? '?'}`
  }

  return (
    <div className={`canvas-node node-condition ${selected ? 'selected' : ''} ${hasError ? 'has-error' : ''}`}>
      <div className="node-header condition">
        <span className="node-icon">📊</span>
        <span className="node-title">指标条件</span>
        {errors.length > 0 && <span className="error-badge">{errors.length}</span>}
      </div>
      <div className="node-body">
        <div className="node-field">
          <span className="field-label">指标</span>
          <span className="field-value">{indicator?.toUpperCase() ?? '未选择'}</span>
        </div>
        <div className="node-field">
          <span className="field-label">条件</span>
          <span className="field-value">{conditionText}</span>
        </div>
        {params.period != null && (
          <div className="node-field">
            <span className="field-label">周期</span>
            <span className="field-value">{params.period}</span>
          </div>
        )}
      </div>
      <Handle type="target" position={Position.Left} id="signal" className="handle-in" />
      <Handle type="source" position={Position.Right} id="condition" className="handle-out" />
    </div>
  )
}
