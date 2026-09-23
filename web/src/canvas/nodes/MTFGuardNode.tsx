import { Position, type NodeProps } from '@xyflow/react'
import type { DSLError, MTFGuardNodeData } from '../types'
import { NodeShell } from './NodeShell'

export default function MTFGuardNode({ data, selected }: NodeProps) {
  const d = data as MTFGuardNodeData & { validationErrors?: DSLError[] }
  const errors = d.validationErrors ?? []
  const invalid = errors.some(e => e.severity === 'error')
  const fastTf = d.fastTimeframe ?? '5m'
  const slowTf = d.slowTimeframe ?? '1h'
  const structureType = d.structureType ?? 'order_block'
  const name = d.name ?? 'MTF Guard'
  const violationPolicy = d.violationPolicy ?? {
    temporaryViolation: 'hold',
    reclaimPending: 'reduce',
    confirmedReclaim: 'resume',
    confirmedBreak: 'exit',
  }

  return (
    <NodeShell
      type="mtfGuard"
      title={name}
      dotColor="var(--pa-node-mtf)"
      rows={[
        { k: '周期对', v: `${fastTf} ↔ ${slowTf}` },
        { k: '结构类型', v: structureType.replace(/_/g, ' ') },
        { k: '临时违反', v: violationPolicy.temporaryViolation },
        { k: '确认突破', v: violationPolicy.confirmedBreak },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'guard-in' },
        { type: 'source', position: Position.Right, id: 'guard-out' },
      ]}
    />
  )
}
