import { useEffect, useCallback, useRef } from 'react'
import type { Dispatch, SetStateAction } from 'react'
import type { Node, Edge } from '@xyflow/react'
import { setBridgeHandler, sendToSwift } from '../bridge'
import { graphToDsl } from '../converters/graphToDsl'
import { dslToGraph } from '../converters/dslToGraph'
import type { SwiftToReactMessage, ValidationReport, AnyRulePackageDSL } from '../types'

interface UseBridgeParams {
  setNodes: Dispatch<SetStateAction<Node[]>>
  setEdges: Dispatch<SetStateAction<Edge[]>>
  setValidation: (report: ValidationReport | null) => void
  onReadOnlyChange?: (readOnly: boolean) => void
}

export function useCanvasBridge({ setNodes, setEdges, setValidation, onReadOnlyChange }: UseBridgeParams) {
  const nodesRef = useRef<Node[]>([])
  const edgesRef = useRef<Edge[]>([])

  const handleMessage = useCallback((msg: SwiftToReactMessage) => {
    switch (msg.type) {
      case 'loadDSL': {
        const dsl = msg.payload.dsl as AnyRulePackageDSL
        const { nodes, edges } = dslToGraph(dsl)
        setNodes(nodes)
        setEdges(edges)
        nodesRef.current = nodes
        edgesRef.current = edges
        setValidation(null)
        break
      }
      case 'loadGraph': {
        const nodes = msg.payload.nodes as Node[]
        const edges = msg.payload.edges as Edge[]
        setNodes(nodes)
        setEdges(edges)
        nodesRef.current = nodes
        edgesRef.current = edges
        setValidation(null)
        break
      }
      case 'validationResult': {
        setValidation(msg.payload)
        break
      }
      case 'setReadOnly': {
        onReadOnlyChange?.(msg.readOnly)
        break
      }
      case 'updateNodeData': {
        setNodes(ns => ns.map(n => n.id === msg.nodeId ? { ...n, data: msg.data } : n))
        break
      }
      case 'mtfGuardStateUpdate': {
        const { guardId, state, reasonCodes } = msg.payload
        // Update all edges whose data.guardId matches
        const updatedEdges = edgesRef.current.map(edge => {
          const edgeData = edge.data as Record<string, unknown> | undefined
          if (edge.type === 'mtfGuard' && edgeData?.guardId === guardId) {
            return {
              ...edge,
              data: {
                ...edgeData,
                guardState: state,
                reasonCodes: reasonCodes ?? [],
              },
            }
          }
          return edge
        })
        edgesRef.current = updatedEdges
        setEdges(updatedEdges)
        break
      }
    }
  }, [setNodes, setEdges, setValidation, onReadOnlyChange])

  useEffect(() => {
    setBridgeHandler(handleMessage)
    sendToSwift({ type: 'canvasReady' })
  }, [handleMessage])

  const notifyGraphChanged = useCallback((nodes: Node[], edges: Edge[]) => {
    nodesRef.current = nodes
    edgesRef.current = edges
    const result = graphToDsl(nodes, edges)
    sendToSwift({
      type: 'graphChanged',
      payload: {
        dsl: result.dsl,
        graphState: JSON.stringify({ nodes, edges }),
      },
    })
  }, [])

  const requestValidation = useCallback(() => {
    const result = graphToDsl(nodesRef.current, edgesRef.current)
    if (result.dsl) {
      sendToSwift({ type: 'requestValidation', payload: { dsl: result.dsl } })
    }
    return result
  }, [])

  const requestSaveVersion = useCallback(() => {
    const result = graphToDsl(nodesRef.current, edgesRef.current)
    if (result.dsl) {
      sendToSwift({ type: 'requestSaveVersion', payload: { dsl: result.dsl } })
    }
    return result
  }, [])

  return { notifyGraphChanged, requestValidation, requestSaveVersion }
}
