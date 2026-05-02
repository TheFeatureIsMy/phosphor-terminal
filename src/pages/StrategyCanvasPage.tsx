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

function DataSourceNode({ data }: { data: { label: string; source: string } }) {
  return (
    <div className="bg-surface rounded-xl p-3 min-w-[160px]" style={{ border: '1px solid rgba(96, 165, 250, 0.25)' }}>
      <div className="flex items-center gap-1.5 mb-1">
        <Database className="w-3.5 h-3.5 text-info" />
        <span className="text-[11px] font-medium text-info tracking-wider uppercase">数据源</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted font-mono mt-0.5">{data.source}</div>
      <Handle type="source" position={Position.Right} className="!bg-info !w-1.5 !h-1.5" />
    </div>
  )
}

function IndicatorNode({ data }: { data: { label: string; params: string } }) {
  return (
    <div className="bg-surface rounded-xl p-3 min-w-[160px]" style={{ border: '1px solid rgba(139, 124, 248, 0.25)' }}>
      <Handle type="target" position={Position.Left} className="!bg-primary !w-1.5 !h-1.5" />
      <div className="flex items-center gap-1.5 mb-1">
        <BarChart3 className="w-3.5 h-3.5 text-primary" />
        <span className="text-[11px] font-medium text-primary tracking-wider uppercase">指标</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted font-mono mt-0.5">{data.params}</div>
      <Handle type="source" position={Position.Right} className="!bg-primary !w-1.5 !h-1.5" />
    </div>
  )
}

function LogicGateNode({ data }: { data: { label: string; condition: string } }) {
  return (
    <div className="bg-surface rounded-xl p-3 min-w-[160px]" style={{ border: '1px solid rgba(110, 231, 240, 0.25)' }}>
      <Handle type="target" position={Position.Left} className="!bg-accent !w-1.5 !h-1.5" />
      <div className="flex items-center gap-1.5 mb-1">
        <GitBranch className="w-3.5 h-3.5 text-accent" />
        <span className="text-[11px] font-medium text-accent tracking-wider uppercase">逻辑门</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted font-mono mt-0.5">{data.condition}</div>
      <Handle type="source" position={Position.Right} className="!bg-accent !w-1.5 !h-1.5" />
    </div>
  )
}

function ExecutorNode({ data }: { data: { label: string; action: string } }) {
  return (
    <div className="bg-surface rounded-xl p-3 min-w-[160px]" style={{ border: '1px solid rgba(52, 211, 153, 0.25)' }}>
      <Handle type="target" position={Position.Left} className="!bg-success !w-1.5 !h-1.5" />
      <div className="flex items-center gap-1.5 mb-1">
        <Zap className="w-3.5 h-3.5 text-success" />
        <span className="text-[11px] font-medium text-success tracking-wider uppercase">执行器</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted font-mono mt-0.5">{data.action}</div>
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
  { id: 'e1-2', source: '1', target: '2', animated: true, style: { stroke: '#60a5fa' } },
  { id: 'e1-3', source: '1', target: '3', animated: true, style: { stroke: '#60a5fa' } },
  { id: 'e2-4', source: '2', target: '4', style: { stroke: '#8b7cf8' } },
  { id: 'e3-4', source: '3', target: '4', style: { stroke: '#8b7cf8' } },
  { id: 'e4-5', source: '4', target: '5', animated: true, style: { stroke: '#34d399' } },
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
    <div className="h-[calc(100vh-10rem)] flex flex-col">
      <div className="flex items-center gap-3 mb-4">
        <button onClick={() => navigate('/strategies')} className="flex items-center gap-1 text-[13px] text-text-secondary hover:text-text-primary transition-colors">
          <ArrowLeft className="w-3.5 h-3.5" /> 返回
        </button>
        <h1 className="text-lg font-semibold">策略画布 #{id}</h1>
        <div className="flex items-center gap-3 ml-auto text-[11px] text-text-muted">
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded bg-info/40" />数据源</span>
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded bg-primary/40" />指标</span>
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded bg-accent/40" />逻辑门</span>
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded bg-success/40" />执行器</span>
        </div>
      </div>

      <div className="flex-1 card overflow-hidden">
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
          <Background color="rgba(255,255,255,0.03)" gap={20} />
          <Controls className="!bg-surface !border-border" />
          <MiniMap
            nodeColor={(node) => {
              switch (node.type) {
                case 'dataSource': return '#60a5fa'
                case 'indicator': return '#8b7cf8'
                case 'logicGate': return '#6ee7f0'
                case 'executor': return '#34d399'
                default: return '#4a5068'
              }
            }}
            className="!bg-surface !border-border"
          />
        </ReactFlow>
      </div>
    </div>
  )
}
