import { BaseEdge, getBezierPath, type EdgeProps } from '@xyflow/react'
import type { MTFGuardEdgeData } from '../types'

type GuardState = MTFGuardEdgeData['guardState']

const STATE_STYLES: Record<GuardState, { stroke: string; strokeDasharray?: string; opacity?: number; animated?: boolean }> = {
  confirmed:             { stroke: '#30D158' },
  watching:              { stroke: '#FF9F0A', animated: true },
  pending_htf_close:     { stroke: '#FF9F0A', strokeDasharray: '8 4' },
  temporary_violation:   { stroke: '#FFD60A', strokeDasharray: '4 4', animated: true },
  reclaim_pending:       { stroke: '#FF9F0A', strokeDasharray: '12 4', animated: true },
  invalidated:           { stroke: '#FF453A', strokeDasharray: '2 6' },
  expired:               { stroke: '#636366', strokeDasharray: '6 4', opacity: 0.45 },
  inactive:               { stroke: '#8E8E93', strokeDasharray: '6 4', opacity: 0.5 },
}

const STATE_LABELS: Record<GuardState, string> = {
  confirmed: 'Confirmed',
  watching: 'Watching',
  pending_htf_close: 'Pending HTF Close',
  temporary_violation: 'Temp Violation',
  reclaim_pending: 'Reclaim Pending',
  invalidated: 'Invalidated',
  expired: 'Expired',
  inactive: 'Inactive',
}

export default function MTFGuardEdge({
  id,
  sourceX, sourceY, targetX, targetY,
  sourcePosition, targetPosition,
  data,
  markerEnd,
}: EdgeProps) {
  const d = data as MTFGuardEdgeData | undefined
  const guardState: GuardState = d?.guardState ?? 'watching'
  const style = STATE_STYLES[guardState]

  const [edgePath, labelX, labelY] = getBezierPath({
    sourceX, sourceY, targetX, targetY,
    sourcePosition, targetPosition,
  })

  const handleClick = () => {
    const dataObj = d as Record<string, unknown> | undefined
    if (dataObj && typeof dataObj.onClick === 'function') {
      (dataObj.onClick as () => void)()
    }
  }

  return (
    <>
      <BaseEdge
        id={id}
        path={edgePath}
        markerEnd={markerEnd}
        style={{
          stroke: style.stroke,
          strokeWidth: 2.5,
          strokeDasharray: style.strokeDasharray,
          opacity: style.opacity ?? 1,
          filter: guardState === 'confirmed' ? 'drop-shadow(0 0 4px rgba(48, 209, 88, 0.4))' : undefined,
          cursor: 'pointer',
        }}
        className={style.animated ? 'mtf-guard-edge-animated' : undefined}
      />
      {/* Invisible wider click target */}
      <path
        d={edgePath}
        fill="none"
        stroke="transparent"
        strokeWidth={16}
        style={{ cursor: 'pointer' }}
        onClick={handleClick}
      />
      {/* State label */}
      <foreignObject
        x={labelX - 50}
        y={labelY - 12}
        width={100}
        height={24}
        requiredExtensions="http://www.w3.org/1999/xhtml"
        style={{ overflow: 'visible', pointerEvents: 'none' }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <span
            style={{
              background: 'rgba(0, 0, 0, 0.75)',
              backdropFilter: 'blur(8px)',
              border: `1px solid ${style.stroke}`,
              borderRadius: '6px',
              padding: '2px 8px',
              fontSize: '10px',
              fontWeight: 600,
              color: style.stroke,
              whiteSpace: 'nowrap',
              letterSpacing: '-0.01em',
            }}
          >
            {STATE_LABELS[guardState]}
          </span>
        </div>
      </foreignObject>
    </>
  )
}
