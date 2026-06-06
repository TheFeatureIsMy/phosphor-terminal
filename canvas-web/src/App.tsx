import { useState, useCallback, useRef, useMemo } from 'react'
import {
  ReactFlow, Controls, MiniMap, Background, BackgroundVariant,
  addEdge, useNodesState, useEdgesState,
  type Connection, type Node, type Edge, type NodeTypes,
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
import { NodeConfigPanel } from './panels/NodeConfigPanel'
import { useCanvasBridge } from './hooks/useCanvasBridge'
import { mapErrorsToNodes } from './hooks/useValidation'
import { graphToDsl } from './converters/graphToDsl'
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
}

interface PaletteEntry {
  type: string
  label: string
  icon: string
  defaultData: Record<string, unknown>
}

const PALETTE: PaletteEntry[] = [
  { type: 'signalInput', label: '信号输入', icon: '📡', defaultData: { timeframe: '1h', symbols: ['BTC/USDT'] } },
  { type: 'indicatorCondition', label: '指标条件', icon: '📊', defaultData: { ruleType: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '<', value: 30 } },
  { type: 'filter', label: '过滤器', icon: '🔍', defaultData: { ruleType: 'volume_filter', indicator: 'volume', operator: '>', value: 1000000 } },
  { type: 'positionSizing', label: '仓位管理', icon: '📐', defaultData: { type: 'fixed_pct', positionPct: 0.02 } },
  { type: 'riskPolicy', label: '风控策略', icon: '🛡️', defaultData: { stoploss: -0.05, maxOpenTrades: 3 } },
  { type: 'executionOutput', label: '执行输出', icon: '🚀', defaultData: { entryLogic: 'AND', exitLogic: 'OR', schemaVersion: '2.5' } },
  { type: 'structureDefense', label: 'Structure Defense', icon: '🛡', defaultData: { structures: ['liquidity_pool', 'fvg'], minStructureScore: 70 } },
  { type: 'accountRisk', label: 'Account Risk', icon: '🔥', defaultData: { maxDailyLoss: 0.03, maxWeeklyLoss: 0.08, maxConsecutiveLosses: 4, killSwitchEnabled: true } },
]

let nodeIdCounter = 100

export default function App() {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([])
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([])
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null)
  const [validation, setValidation] = useState<ValidationReport | null>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const nodesRef = useRef<Node[]>([])
  const edgesRef = useRef<Edge[]>([])

  nodesRef.current = nodes
  edgesRef.current = edges

  const bridgeSetNodes = useCallback((n: Node[]) => setNodes(n), [setNodes])
  const bridgeSetEdges = useCallback((e: Edge[]) => setEdges(e), [setEdges])

  const { notifyGraphChanged, requestValidation, requestSaveVersion } = useCanvasBridge({
    setNodes: bridgeSetNodes,
    setEdges: bridgeSetEdges,
    setValidation,
  })

  const selectedNode = useMemo(
    () => nodes.find(n => n.id === selectedNodeId) ?? null,
    [nodes, selectedNodeId]
  )

  const displayNodes = useMemo(() => {
    if (!validation) return nodes
    return mapErrorsToNodes(nodes, edges, validation)
  }, [nodes, edges, validation])

  const onConnect = useCallback((conn: Connection) => {
    setEdges(eds => addEdge(conn, eds))
  }, [setEdges])

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    setSelectedNodeId(node.id)
  }, [])

  const onPaneClick = useCallback(() => {
    setSelectedNodeId(null)
  }, [])

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

  const updateNodeData = useCallback((id: string, data: Record<string, unknown>) => {
    setNodes(nds => nds.map(n => n.id === id ? { ...n, data } : n))
    scheduleNotify()
  }, [setNodes, scheduleNotify])

  const handleValidate = useCallback(() => {
    const result = graphToDsl(nodesRef.current, edgesRef.current)
    if (result.errors.length > 0) {
      setValidation({
        valid: false, errorCount: result.errors.length, warningCount: result.warnings.length,
        safeHoldRequired: false, safeHoldReasons: [],
        errors: result.errors.map(e => ({ code: 'GRAPH_ERROR', path: '', message: e.message, severity: 'error' as const })),
        warnings: result.warnings.map(w => ({ code: 'GRAPH_WARNING', path: '', message: w.message, severity: 'warning' as const })),
      })
      return
    }
    requestValidation()
  }, [requestValidation])

  const handleSave = useCallback(() => {
    const result = graphToDsl(nodesRef.current, edgesRef.current)
    if (result.errors.length > 0 || !result.dsl) return
    requestSaveVersion()
  }, [requestSaveVersion])

  const dslResult = useMemo(() => graphToDsl(nodes, edges), [nodes, edges])

  return (
    <div className="app-container">
      <div className="node-palette">
        <div className="palette-title">组件</div>
        {PALETTE.map(entry => (
          <div key={entry.type} className="palette-item" onClick={() => addNode(entry)}>
            <span className="palette-icon">{entry.icon}</span>
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
          onNodeClick={onNodeClick}
          onPaneClick={onPaneClick}
          nodeTypes={nodeTypes}
          fitView
          deleteKeyCode="Delete"
          multiSelectionKeyCode="Meta"
          defaultEdgeOptions={{
            type: 'smoothstep',
            animated: false,
          }}
        >
          <Background variant={BackgroundVariant.Dots} gap={24} size={1} color="rgba(255,255,255,0.03)" />
          <Controls position="bottom-left" />
          <MiniMap
            position="bottom-right"
            nodeColor={(n) => {
              const colors: Record<string, string> = {
                signalInput: '#64D2FF', indicatorCondition: '#BF5AF2',
                filter: '#FF9F0A', positionSizing: '#30D158',
                riskPolicy: '#FF453A', executionOutput: '#5E5CE6',
              }
              return colors[n.type ?? ''] ?? '#636366'
            }}
            maskColor="rgba(0, 0, 0, 0.7)"
            pannable
            zoomable
          />
        </ReactFlow>

        <div className="canvas-toolbar">
          <button className="toolbar-btn" onClick={handleValidate}>验证</button>
          <button className="toolbar-btn primary" onClick={handleSave}
            disabled={!dslResult.dsl || (validation != null && !validation.valid)}>
            保存
          </button>
        </div>

        <div className="status-bar">
          <span>{nodes.length} 节点 · {edges.length} 连线</span>
          <span>
            {validation == null ? '未验证' :
             validation.valid ? <span className="status-valid">● 验证通过</span> :
             <span className="status-invalid">● {validation.errorCount} 错误 · {validation.warningCount} 警告</span>}
          </span>
        </div>
      </div>

      {selectedNode && (
        <NodeConfigPanel
          node={selectedNode}
          onUpdate={updateNodeData}
          onClose={() => setSelectedNodeId(null)}
        />
      )}
    </div>
  )
}
