import { useState, useCallback, useRef, useMemo, useEffect } from 'react'
import {
  ReactFlow, Controls, MiniMap, Background, BackgroundVariant,
  addEdge, useNodesState, useEdgesState,
  type Connection, type Node, type Edge, type NodeTypes, type EdgeTypes,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'

import { SignalInputNode } from './nodes/SignalInputNode'
import { IndicatorConditionNode } from './nodes/IndicatorConditionNode'
import { FilterNode } from './nodes/FilterNode'
import { PositionSizingNode } from './nodes/PositionSizingNode'
import { RiskPolicyNode } from './nodes/RiskPolicyNode'
import { ExecutionOutputNode } from './nodes/ExecutionOutputNode'
import StructureDefenseNode from './nodes/StructureDefenseNode'
import AccountRiskNode from './nodes/AccountRiskNode'
import MTFGuardNode from './nodes/MTFGuardNode'
import MTFGuardEdge from './edges/MTFGuardEdge'
import { useCanvasBridge } from './hooks/useCanvasBridge'
import { mapErrorsToNodes } from './hooks/useValidation'
import { sendToSwift } from './bridge'
import type { ValidationReport } from './types'

const nodeTypes: NodeTypes = {
  signalInput: SignalInputNode,
  indicatorCondition: IndicatorConditionNode,
  filter: FilterNode,
  positionSizing: PositionSizingNode,
  riskPolicy: RiskPolicyNode,
  executionOutput: ExecutionOutputNode,
  structureDefense: StructureDefenseNode,
  accountRisk: AccountRiskNode,
  mtfGuard: MTFGuardNode,
}

const edgeTypes: EdgeTypes = {
  mtfGuard: MTFGuardEdge,
}

interface PaletteEntry {
  type: string
  label: string
  defaultData: Record<string, unknown>
}

const PALETTE: PaletteEntry[] = [
  { type: 'signalInput', label: '信号输入', defaultData: { timeframe: '1h', symbols: ['BTC/USDT'] } },
  { type: 'indicatorCondition', label: '指标条件', defaultData: { ruleType: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '<', value: 30 } },
  { type: 'filter', label: '过滤器', defaultData: { ruleType: 'volume_filter', indicator: 'volume', operator: '>', value: 1000000 } },
  { type: 'positionSizing', label: '仓位管理', defaultData: { type: 'fixed_pct', positionPct: 0.02 } },
  { type: 'riskPolicy', label: '风控策略', defaultData: { stoploss: -0.05, maxOpenTrades: 3 } },
  { type: 'executionOutput', label: '执行输出', defaultData: { entryLogic: 'AND', exitLogic: 'OR', schemaVersion: '2.5' } },
  { type: 'structureDefense', label: 'Structure Defense', defaultData: { structures: ['liquidity_pool', 'fvg'], minStructureScore: 70 } },
  { type: 'accountRisk', label: 'Account Risk', defaultData: { maxDailyLoss: 0.03, maxWeeklyLoss: 0.08, maxConsecutiveLosses: 4, killSwitchEnabled: true } },
  { type: 'mtfGuard', label: 'MTF Guard', defaultData: { guardId: '', name: 'MTF Guard', fastTimeframe: '5m', slowTimeframe: '1h', sourceNode: '', targetNode: '', structureType: 'order_block', shadowWindow: { mode: 'strict', maxFastCandles: 12, allowLowTfTouch: false, allowLowTfUpdateFilledRatio: false }, violationPolicy: { temporaryViolation: 'hold', reclaimPending: 'reduce', confirmedReclaim: 'resume', confirmedBreak: 'exit' } } },
]

const MINIMAP_COLORS: Record<string, string> = {
  signalInput: 'var(--pa-node-signal)',
  indicatorCondition: 'var(--pa-node-condition)',
  filter: 'var(--pa-node-filter)',
  positionSizing: 'var(--pa-node-sizing)',
  riskPolicy: 'var(--pa-node-risk)',
  executionOutput: 'var(--pa-node-output)',
  structureDefense: 'var(--pa-node-structure)',
  accountRisk: 'var(--pa-node-account)',
  mtfGuard: 'var(--pa-node-mtf)',
}

let nodeIdCounter = 100

export default function App() {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([])
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([])
  const [validation, setValidation] = useState<ValidationReport | null>(null)
  const [readOnly, setReadOnly] = useState(false)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const nodesRef = useRef<Node[]>([])
  const edgesRef = useRef<Edge[]>([])

  nodesRef.current = nodes
  edgesRef.current = edges

  const bridgeSetNodes = useCallback((n: Node[] | ((prev: Node[]) => Node[])) => setNodes(n), [setNodes])
  const bridgeSetEdges = useCallback((e: Edge[] | ((prev: Edge[]) => Edge[])) => setEdges(e), [setEdges])

  const { notifyGraphChanged } = useCanvasBridge({
    setNodes: bridgeSetNodes,
    setEdges: bridgeSetEdges,
    setValidation,
    onReadOnlyChange: setReadOnly,
  })

  const displayNodes = useMemo(() => {
    if (!validation) return nodes
    return mapErrorsToNodes(nodes, edges, validation)
  }, [nodes, edges, validation])

  const onConnect = useCallback((conn: Connection) => {
    setEdges(eds => addEdge(conn, eds))
  }, [setEdges])

  const onSelectionChange = useCallback(({ nodes }: { nodes: Node[] }) => {
    const sel = nodes[0] ?? null
    sendToSwift({
      type: 'selectionChanged',
      selectedNode: sel ? { id: sel.id, type: sel.type ?? '', data: sel.data as Record<string, unknown> } : null,
    })
  }, [])

  useEffect(() => {
    sendToSwift({
      type: 'graphStats',
      nodeCount: nodes.length,
      edgeCount: edges.length,
      validation: validation == null ? 'unvalidated' : validation.valid ? 'valid' : 'invalid',
    })
  }, [nodes.length, edges.length, validation?.valid])

  const scheduleNotify = useCallback(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => {
      notifyGraphChanged(nodesRef.current, edgesRef.current)
    }, 500)
  }, [notifyGraphChanged])

  const handleNodesChange: typeof onNodesChange = useCallback((changes) => {
    onNodesChange(changes)
    scheduleNotify()
  }, [onNodesChange, scheduleNotify])

  const handleEdgesChange: typeof onEdgesChange = useCallback((changes) => {
    onEdgesChange(changes)
    scheduleNotify()
  }, [onEdgesChange, scheduleNotify])

  const handleConnect = useCallback((conn: Connection) => {
    onConnect(conn)
    scheduleNotify()
  }, [onConnect, scheduleNotify])

  const addNode = useCallback((entry: PaletteEntry) => {
    const id = `canvas_${++nodeIdCounter}`
    const newNode: Node = {
      id,
      type: entry.type,
      position: { x: 200 + Math.random() * 200, y: 100 + Math.random() * 200 },
      data: { ...entry.defaultData },
    }
    setNodes(nds => [...nds, newNode])
    scheduleNotify()
  }, [setNodes, scheduleNotify])

  return (
    <div className="app-container">
      <div className="node-palette">
        {PALETTE.map(entry => (
          <div
            key={entry.type}
            className={`palette-item${readOnly ? ' palette-readonly' : ''}`}
            onClick={readOnly ? undefined : () => addNode(entry)}
          >
            <span className="palette-label">{entry.label}</span>
          </div>
        ))}
      </div>

      <div className="canvas-area">
        <ReactFlow
          nodes={displayNodes}
          edges={edges}
          onNodesChange={handleNodesChange}
          onEdgesChange={handleEdgesChange}
          onConnect={handleConnect}
          onSelectionChange={onSelectionChange}
          nodesDraggable={!readOnly}
          nodesConnectable={!readOnly}
          elementsSelectable={true}
          nodeTypes={nodeTypes}
          edgeTypes={edgeTypes}
          fitView
          deleteKeyCode={readOnly ? null : 'Delete'}
          multiSelectionKeyCode="Meta"
          defaultEdgeOptions={{
            type: 'smoothstep',
            animated: false,
            style: { strokeWidth: 1.5 },
          }}
        >
          <Background variant={BackgroundVariant.Dots} gap={24} size={1} color="rgba(255,255,255,0.030)" />
          <Controls position="bottom-left" />
          <MiniMap
            position="bottom-right"
            nodeColor={(n) => MINIMAP_COLORS[n.type ?? ''] ?? 'var(--pa-text-muted)'}
            maskColor="rgba(0, 0, 0, 0.7)"
            pannable
            zoomable
          />
        </ReactFlow>
      </div>
    </div>
  )
}
