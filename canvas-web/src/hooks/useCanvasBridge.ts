import { useEffect, useCallback, useRef } from 'react'
import type { Node, Edge } from '@xyflow/react'
import { setBridgeHandler, sendToSwift } from '../bridge'
import { graphToDsl } from '../converters/graphToDsl'
import { dslToGraph } from '../converters/dslToGraph'
import type { SwiftToReactMessage, ValidationReport, RulePackageDSL } from '../types'

interface UseBridgeParams {
  setNodes: (nodes: Node[]) => void
  setEdges: (edges: Edge[]) => void
  setValidation: (report: ValidationReport | null) => void
}

export function useCanvasBridge({ setNodes, setEdges, setValidation }: UseBridgeParams) {
  const nodesRef = useRef<Node[]>([])
  const edgesRef = useRef<Edge[]>([])

  const handleMessage = useCallback((msg: SwiftToReactMessage) => {
    switch (msg.type) {
      case 'loadDSL': {
        const { nodes, edges } = dslToGraph(msg.payload.dsl)
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
    }
  }, [setNodes, setEdges, setValidation])

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
