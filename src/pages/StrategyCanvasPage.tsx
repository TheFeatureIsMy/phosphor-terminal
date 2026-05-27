import { useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ReactFlow, Background, Controls, MiniMap,
  addEdge, useNodesState, useEdgesState,
  type Node, type Edge, type OnConnect,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { ArrowLeft } from 'lucide-react'
import { canvasNodeTypes, defaultCanvasNodes, defaultCanvasEdges } from '@/components/canvas/CanvasNodes'

export function StrategyCanvasPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [nodes, , onNodesChange] = useNodesState(defaultCanvasNodes as Node[])
  const [edges, setEdges, onEdgesChange] = useEdgesState(defaultCanvasEdges as Edge[])

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
          nodeTypes={canvasNodeTypes}
          fitView
          className="bg-background"
        >
          <Background color="rgba(255,255,255,0.03)" gap={20} />
          <Controls className="!bg-surface !border-border" />
          <MiniMap
            nodeColor={(node) => {
              switch (node.type) {
                case 'dataSource': return '#00c2ff'
                case 'indicator': return '#00ff9d'
                case 'logicGate': return '#ffb800'
                case 'executor': return '#00ff9d'
                default: return '#334155'
              }
            }}
            className="!bg-surface !border-border"
          />
        </ReactFlow>
      </div>
    </div>
  )
}
