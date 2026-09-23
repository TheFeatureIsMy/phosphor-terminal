import { useCallback } from 'react'
import type { Node } from '@xyflow/react'
import type { ValidationReport, DSLError } from '../types'

export function mapErrorsToNodes(
  nodes: Node[],
  edges: { source: string; target: string; targetHandle?: string | null }[],
  report: ValidationReport,
): Node[] {
  const nodeErrors = new Map<string, DSLError[]>()

  const outputNode = nodes.find(n => n.type === 'executionOutput')
  const signalNode = nodes.find(n => n.type === 'signalInput')

  const entryEdges = edges.filter(e => e.target === outputNode?.id && e.targetHandle === 'entryConditions')
  const exitEdges = edges.filter(e => e.target === outputNode?.id && e.targetHandle === 'exitConditions')
  const filterEdges = edges.filter(e => e.target === outputNode?.id && e.targetHandle === 'filters')

  const allErrors = [...report.errors, ...report.warnings]

  for (const err of allErrors) {
    const path = err.path
    let targetId: string | undefined

    if (path.startsWith('entry.rules[')) {
      const idx = parseInt(path.match(/\[(\d+)\]/)?.[1] ?? '0')
      targetId = entryEdges[idx]?.source
    } else if (path.startsWith('exit.rules[')) {
      const idx = parseInt(path.match(/\[(\d+)\]/)?.[1] ?? '0')
      targetId = exitEdges[idx]?.source
    } else if (path.startsWith('filters[')) {
      const idx = parseInt(path.match(/\[(\d+)\]/)?.[1] ?? '0')
      targetId = filterEdges[idx]?.source
    } else if (path.startsWith('risk')) {
      targetId = nodes.find(n => n.type === 'riskPolicy')?.id
    } else if (path.startsWith('position_sizing')) {
      targetId = nodes.find(n => n.type === 'positionSizing')?.id
    } else if (path === 'timeframe' || path === 'symbols' || path.startsWith('symbols[')) {
      targetId = signalNode?.id
    } else if (path === 'schema_version') {
      targetId = outputNode?.id
    }

    if (targetId) {
      const list = nodeErrors.get(targetId) ?? []
      list.push(err)
      nodeErrors.set(targetId, list)
    }
  }

  return nodes.map(n => ({
    ...n,
    data: {
      ...n.data,
      validationErrors: nodeErrors.get(n.id) ?? [],
    },
  }))
}

export function useValidationMapping() {
  return useCallback(mapErrorsToNodes, [])
}
