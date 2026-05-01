import { useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ReactFlow, Background, Controls, MiniMap,
  addEdge, useNodesState, useEdgesState,
  type Node, type Edge, type OnConnect, type NodeTypes,
  Handle, Position
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { Database, BarChart3, GitBranch, Zap, ArrowLeft } from 'lucide-react'

// Custom Node Components
function DataSourceNode({ data }: { data: { label: string; source: string } }) {
  return (
    <div className="bg-surface border border-info/50 rounded-lg p-3 min-w-[160px] shadow-lg">
      <div className="flex items-center gap-2 mb-1">
        <Database className="w-4 h-4 text-info" />
        <span className="text-xs font-medium text-info">数据源</span>
      </div>
      <div className="text-sm font-medium text-text-primary">{data.label}</div>
      <div className="text-xs text-text-muted mt-1">{data.source}</div>
      <Handle type="source" position={Position.Right} className="!bg-info" />
    </div>
  )
}

function IndicatorNode({ data }: { data: { label: string; params: string } }) {
  return (
    <div className="bg-surface border border-primary/50 rounded-lg p-3 min-w-[160px] shadow-lg">
      <Handle type="target" position={Position.Left} className="!bg-primary" />
      <div className="flex items-center gap-2 mb-1">
        <BarChart3 className="w-4 h-4 text-primary" />
        <span className="text-xs font-medium text-primary">指标</span>
      </div>
      <div className="text-sm font-medium text-text-primary">{data.label}</div>
      <div className="text-xs text-text-muted mt-1">{data.params}</div>
      <Handle type="source" position={Position.Right} className="!bg-primary" />
    </div>
  )
}

function LogicGateNode({ data }: { data: { label: string; condition: string } }) {
  return (
    <div className="bg-surface border border-warning/50 rounded-lg p-3 min-w-[160px] shadow-lg">
      <Handle type="target" position={Position.Left} className="!bg-warning" />
      <div className="flex items-center gap-2 mb-1">
        <GitBranch className="w-4 h-4 text-warning" />
        <span className="text-xs font-medium text-warning">逻辑门</span>
      </div>
      <div className="text-sm font-medium text-text-primary">{data.label}</div>
      <div className="text-xs text-text-muted mt-1">{data.condition}</div>
      <Handle type="source" position={Position.Right} className="!bg-warning" />
    </div>
  )
}

function ExecutorNode({ data }: { data: { label: string; action: string } }) {
  return (
    <div className="bg-surface border border-success/50 rounded-lg p-3 min-w-[160px] shadow-lg">
      <Handle type="target" position={Position.Left} className="!bg-success" />
      <div className="flex items-center gap-2 mb-1">
        <Zap className="w-4 h-4 text-success" />
        <span className="text-xs font-medium text-success">执行器</span>
      </div>
      <div className="text-sm font-medium text-text-primary">{data.label}</div>
      <div className="text-xs text-text-muted mt-1">{data.action}</div>
    </div>
  )
}

const nodeTypes: NodeTypes = {
  dataSource: DataSourceNode,
  indicator: IndicatorNode,
  logicGate: LogicGateNode,
  executor: ExecutorNode,
}

const initialNodes: Node[] = [
  { id: '1', type: 'dataSource', position: { x: 50, y: 100 }, data: { label: 'Binance K线', source: 'BTC/USDT 1h' } },
  { id: '2', type: 'indicator', position: { x: 300, y: 50 }, data: { label: 'RSI', params: 'period=14' } },
  { id: '3', type: 'indicator', position: { x: 300, y: 180 }, data: { label: 'SMA', params: 'period=50' } },
  { id: '4', type: 'logicGate', position: { x: 550, y: 100 }, data: { label: '买入条件', condition: 'RSI < 30 AND close > SMA' } },
  { id: '5', type: 'executor', position: { x: 800, y: 100 }, data: { label: '市价买入', action: 'BUY BTC/USDT' } },
]

const initialEdges: Edge[] = [
  { id: 'e1-2', source: '1', target: '2', animated: true, style: { stroke: '#06b6d4' } },
  { id: 'e1-3', source: '1', target: '3', animated: true, style: { stroke: '#06b6d4' } },
  { id: 'e2-4', source: '2', target: '4', style: { stroke: '#3b82f6' } },
  { id: 'e3-4', source: '3', target: '4', style: { stroke: '#3b82f6' } },
  { id: 'e4-5', source: '4', target: '5', animated: true, style: { stroke: '#10b981' } },
]

export function StrategyCanvasPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [nodes, , onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)

  const onConnect: OnConnect = useCallback(
    (params) => setEdges(eds => addEdge({ ...params, animated: true }, eds)),
    [setEdges]
  )

  return (
    <div className="h-[calc(100vh-11rem)] flex flex-col">
      <div className="flex items-center gap-4 mb-4">
        <button
          onClick={() => navigate('/strategies')}
          className="flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary transition-colors"
        >
          <ArrowLeft className="w-4 h-4" /> 返回
        </button>
        <h1 className="text-xl font-bold">策略画布 #{id}</h1>
        <div className="flex items-center gap-2 ml-auto">
          <div className="flex items-center gap-1 text-xs text-text-muted">
            <span className="w-3 h-3 rounded bg-info/50" /> 数据源
            <span className="w-3 h-3 rounded bg-primary/50 ml-2" /> 指标
            <span className="w-3 h-3 rounded bg-warning/50 ml-2" /> 逻辑门
            <span className="w-3 h-3 rounded bg-success/50 ml-2" /> 执行器
          </div>
        </div>
      </div>

      <div className="flex-1 bg-surface rounded-xl border border-border overflow-hidden">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          nodeTypes={nodeTypes}
          fitView
          className="bg-background"
        >
          <Background color="#1f2937" gap={20} />
          <Controls className="!bg-surface !border-border !text-text-primary" />
          <MiniMap
            nodeColor={(node) => {
              switch (node.type) {
                case 'dataSource': return '#06b6d4'
                case 'indicator': return '#3b82f6'
                case 'logicGate': return '#f59e0b'
                case 'executor': return '#10b981'
                default: return '#6b7280'
              }
            }}
            className="!bg-surface !border-border"
          />
        </ReactFlow>
      </div>
    </div>
  )
}
