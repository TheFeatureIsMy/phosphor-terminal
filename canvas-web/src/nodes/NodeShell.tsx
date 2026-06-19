import { Handle, Position } from '@xyflow/react'
import type { CSSProperties, ReactNode } from 'react'

export type NodePort = {
  id?: string
  type: 'source' | 'target'
  position: Position
  style?: CSSProperties
  className?: string
}

export type NodeRow = {
  k: string
  v: ReactNode
}

export interface NodeShellProps {
  type: string
  title: string
  dotColor: string
  rows: NodeRow[]
  selected?: boolean
  invalid?: boolean
  errMessage?: string
  ports: NodePort[]
}

export function NodeShell({
  type, title, dotColor, rows, selected, invalid, errMessage, ports,
}: NodeShellProps) {
  const classes = ['pa-node']
  if (selected) classes.push('is-selected')
  if (invalid) classes.push('is-invalid')

  return (
    <div className={classes.join(' ')} data-node-type={type}>
      <div className="pa-node-header">
        <span className="pa-node-dot" style={{ background: dotColor }} aria-hidden />
        <span className="pa-node-type">{type}</span>
        <span className="pa-node-title" title={title}>{title}</span>
      </div>

      {rows.length > 0 && (
        <div className="pa-node-body">
          {rows.map((row, i) => (
            <RowFragment key={i} row={row} />
          ))}
        </div>
      )}

      {invalid && errMessage && (
        <div className="pa-node-error" role="alert">{errMessage}</div>
      )}

      {ports.map((p, i) => (
        <Handle
          key={`${p.type}-${p.id ?? i}`}
          type={p.type}
          position={p.position}
          id={p.id}
          className={p.className ? `pa-handle ${p.className}` : 'pa-handle'}
          style={p.style}
        />
      ))}
    </div>
  )
}

function RowFragment({ row }: { row: NodeRow }) {
  return (
    <>
      <span className="pa-node-row-key">{row.k}</span>
      <span className="pa-node-row-val">{row.v}</span>
    </>
  )
}
