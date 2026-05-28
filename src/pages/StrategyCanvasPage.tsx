import { useCallback, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ReactFlow, Background, Controls, MiniMap,
  addEdge, useNodesState, useEdgesState,
  type Node, type Edge, type OnConnect,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import { ArrowLeft, Plus, Play, Save, Code, Trash2, ChevronRight, ChevronDown } from 'lucide-react'
import { canvasNodeTypes, paletteCategories, defaultCanvasNodes, defaultCanvasEdges } from '@/components/canvas/CanvasNodes'

export function StrategyCanvasPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [nodes, setNodes, onNodesChange] = useNodesState(defaultCanvasNodes as Node[])
  const [edges, setEdges, onEdgesChange] = useEdgesState(defaultCanvasEdges as Edge[])
  const [selectedNode, setSelectedNode] = useState<Node | null>(null)
  const [collapsedCategories, setCollapsedCategories] = useState<Record<string, boolean>>({})

  const onConnect: OnConnect = useCallback(
    (params) => setEdges(eds => addEdge({ ...params, animated: true, style: { stroke: '#8cffb8' } }, eds)),
    [setEdges]
  )

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    setSelectedNode(node)
  }, [])

  const onPaneClick = useCallback(() => {
    setSelectedNode(null)
  }, [])

  const addNode = useCallback((type: string, data: Record<string, unknown>) => {
    const newNode: Node = {
      id: `node-${Date.now()}`,
      type,
      position: { x: 400 + Math.random() * 200, y: 200 + Math.random() * 200 },
      data,
    }
    setNodes(nds => [...nds, newNode])
  }, [setNodes])

  const deleteSelectedNode = useCallback(() => {
    if (!selectedNode) return
    setNodes(nds => nds.filter(n => n.id !== selectedNode.id))
    setEdges(eds => eds.filter(e => e.source !== selectedNode.id && e.target !== selectedNode.id))
    setSelectedNode(null)
  }, [selectedNode, setNodes, setEdges])

  const updateNodeData = useCallback((key: string, value: string) => {
    if (!selectedNode) return
    setNodes(nds => nds.map(n =>
      n.id === selectedNode.id
        ? { ...n, data: { ...n.data, [key]: value } }
        : n
    ))
    setSelectedNode(prev => prev ? { ...prev, data: { ...prev.data, [key]: value } } : null)
  }, [selectedNode, setNodes])

  const toggleCategory = (label: string) => {
    setCollapsedCategories(prev => ({ ...prev, [label]: !prev[label] }))
  }

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col gap-3">
      {/* ===== HEADER ===== */}
      <div className="flex items-center gap-3">
        <button onClick={() => navigate('/strategies')} className="flex items-center gap-1 text-[13px] font-mono transition-colors" style={{ color: '#9aa8a0' }}>
          <ArrowLeft className="w-3.5 h-3.5" /> 返回
        </button>
        <div className="w-px h-4" style={{ background: 'rgba(255,255,255,0.08)' }} />
        <h1 className="text-lg font-semibold" style={{ fontFamily: 'Instrument Sans, sans-serif', color: '#e7f0ea' }}>策略画布 #{id}</h1>
        <div className="flex items-center gap-2 ml-auto">
          <button className="flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-mono font-medium transition-colors"
            style={{ background: 'rgba(140,255,184,0.08)', color: '#8cffb8', border: '1px solid rgba(140,255,184,0.2)', borderRadius: '4px' }}>
            <Save className="w-3 h-3" /> 保存
          </button>
          <button className="flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-mono font-medium transition-colors"
            style={{ background: 'rgba(140,255,184,0.12)', color: '#8cffb8', border: '1px solid rgba(140,255,184,0.25)', borderRadius: '4px' }}>
            <Play className="w-3 h-3" /> 运行回测
          </button>
          <button className="flex items-center gap-1.5 px-3 py-1.5 text-[11px] font-mono font-medium transition-colors"
            style={{ background: 'rgba(139,124,248,0.12)', color: '#8b7cf8', border: '1px solid rgba(139,124,248,0.25)', borderRadius: '4px' }}>
            <Code className="w-3 h-3" /> 生成代码
          </button>
        </div>
      </div>

      {/* ===== MAIN AREA ===== */}
      <div className="flex-1 flex gap-3 overflow-hidden min-h-0">

        {/* ===== LEFT: Node Palette ===== */}
        <div className="w-[200px] shrink-0 card p-3 overflow-y-auto self-start" style={{ maxHeight: 'calc(100vh - 10rem)' }}>
          <div className="text-[10px] font-semibold tracking-wider uppercase pb-2 mb-2" style={{ color: '#5e6a63', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
            节点面板
          </div>
          {paletteCategories.map(cat => (
            <div key={cat.label} className="mb-1">
              <button
                onClick={() => toggleCategory(cat.label)}
                className="w-full flex items-center justify-between px-2 py-1.5 text-[10px] font-medium tracking-wider uppercase transition-colors"
                style={{ color: '#9aa8a0', borderRadius: '4px' }}
              >
                <span>{cat.label}</span>
                {collapsedCategories[cat.label] ? <ChevronRight className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
              </button>
              {!collapsedCategories[cat.label] && (
                <div className="space-y-0.5 mt-0.5">
                  {cat.items.map(item => (
                    <button
                      key={item.label}
                      onClick={() => addNode(item.type, item.defaultData)}
                      className="w-full flex items-center gap-2 px-2 py-1.5 text-[11px] font-mono transition-all duration-100 group"
                      style={{ color: '#9aa8a0', borderRadius: '4px', border: '1px solid transparent' }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = `${item.color}08`
                        e.currentTarget.style.borderColor = `${item.color}20`
                        e.currentTarget.style.color = '#e7f0ea'
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'transparent'
                        e.currentTarget.style.borderColor = 'transparent'
                        e.currentTarget.style.color = '#9aa8a0'
                      }}
                    >
                      <div className="w-5 h-5 flex items-center justify-center rounded shrink-0" style={{ background: `${item.color}12` }}>
                        <item.icon className="w-3 h-3" style={{ color: item.color }} />
                      </div>
                      <span className="truncate">{item.label}</span>
                      <Plus className="w-3 h-3 ml-auto opacity-0 group-hover:opacity-60 transition-opacity shrink-0" />
                    </button>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        {/* ===== CENTER: ReactFlow Canvas ===== */}
        <div className="flex-1 card overflow-hidden">
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onNodeClick={onNodeClick}
            onPaneClick={onPaneClick}
            nodeTypes={canvasNodeTypes}
            fitView
            className="bg-background"
          >
            <Background color="rgba(255,255,255,0.03)" gap={20} />
            <Controls className="!bg-surface !border-border" />
            <MiniMap
              nodeColor={(node) => {
                switch (node.type) {
                  case 'dataSource': return '#7db7ff'
                  case 'indicator': return '#8cffb8'
                  case 'logicGate': return '#e8b86d'
                  case 'executor': return '#34d399'
                  case 'ai': return '#a855f7'
                  case 'risk': return '#ff6b6b'
                  default: return '#334155'
                }
              }}
              className="!bg-surface !border-border"
            />
          </ReactFlow>
        </div>

        {/* ===== RIGHT: Node Settings Panel ===== */}
        <div className="w-[260px] shrink-0 card overflow-y-auto" style={{ maxHeight: 'calc(100vh - 10rem)' }}>
          {selectedNode ? (
            <div className="p-4">
              <div className="flex items-center justify-between mb-4">
                <span className="text-[11px] font-semibold tracking-wider uppercase" style={{ color: '#5e6a63' }}>节点设置</span>
                <button
                  onClick={deleteSelectedNode}
                  className="p-1.5 transition-colors"
                  style={{ color: '#5e6a63', borderRadius: '4px' }}
                  onMouseEnter={(e) => { e.currentTarget.style.color = '#ff6b6b'; e.currentTarget.style.background = 'rgba(255,107,107,0.08)' }}
                  onMouseLeave={(e) => { e.currentTarget.style.color = '#5e6a63'; e.currentTarget.style.background = 'transparent' }}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Node type badge */}
              <div className="flex items-center gap-2 mb-4 p-2.5 rounded-lg" style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid rgba(255,255,255,0.05)' }}>
                <div className="w-7 h-7 flex items-center justify-center rounded" style={{
                  background: selectedNode.type === 'dataSource' ? 'rgba(125,183,255,0.1)' :
                    selectedNode.type === 'indicator' ? 'rgba(140,255,184,0.1)' :
                    selectedNode.type === 'ai' ? 'rgba(168,85,247,0.1)' :
                    selectedNode.type === 'logicGate' ? 'rgba(232,184,109,0.1)' :
                    selectedNode.type === 'risk' ? 'rgba(255,107,107,0.1)' :
                    'rgba(52,211,153,0.1)'
                }}>
                  <span className="text-[11px] font-bold" style={{
                    color: selectedNode.type === 'dataSource' ? '#7db7ff' :
                      selectedNode.type === 'indicator' ? '#8cffb8' :
                      selectedNode.type === 'ai' ? '#a855f7' :
                      selectedNode.type === 'logicGate' ? '#e8b86d' :
                      selectedNode.type === 'risk' ? '#ff6b6b' :
                      '#34d399'
                  }}>
                    {selectedNode.type === 'dataSource' ? '数据' :
                     selectedNode.type === 'indicator' ? '指标' :
                     selectedNode.type === 'ai' ? 'AI' :
                     selectedNode.type === 'logicGate' ? '逻辑' :
                     selectedNode.type === 'risk' ? '风控' :
                     '执行'}
                  </span>
                </div>
                <div>
                  <div className="text-[12px] font-mono font-medium" style={{ color: '#e7f0ea' }}>
                    {(selectedNode.data as Record<string, unknown>).label as string || '节点'}
                  </div>
                  <div className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>ID: {selectedNode.id}</div>
                </div>
              </div>

              {/* Editable fields */}
              <div className="space-y-3">
                {Object.entries(selectedNode.data as Record<string, unknown>).map(([key, value]) => {
                  if (key === 'label') return null
                  const label = key === 'source' ? '数据源' :
                    key === 'detail' ? '详情' :
                    key === 'params' ? '参数' :
                    key === 'condition' ? '条件' :
                    key === 'action' ? '动作' :
                    key === 'model' ? '模型' :
                    key === 'confidence' ? '置信度' :
                    key === 'rule' ? '规则' :
                    key === 'severity' ? '严重级别' :
                    key === 'value' ? '当前值' :
                    key === 'operator' ? '运算符' :
                    key
                  return (
                    <div key={key}>
                      <label className="text-[10px] font-mono tracking-wider uppercase block mb-1" style={{ color: '#5e6a63' }}>{label}</label>
                      <input
                        type="text"
                        value={String(value ?? '')}
                        onChange={(e) => updateNodeData(key, e.target.value)}
                        className="w-full px-3 py-2 text-[12px] font-mono"
                        style={{
                          background: 'rgba(255,255,255,0.03)',
                          border: '1px solid rgba(255,255,255,0.08)',
                          borderRadius: '4px',
                          color: '#e7f0ea',
                        }}
                      />
                    </div>
                  )
                })}

                {/* Label field */}
                <div>
                  <label className="text-[10px] font-mono tracking-wider uppercase block mb-1" style={{ color: '#5e6a63' }}>名称</label>
                  <input
                    type="text"
                    value={(selectedNode.data as Record<string, unknown>).label as string || ''}
                    onChange={(e) => updateNodeData('label', e.target.value)}
                    className="w-full px-3 py-2 text-[12px] font-mono"
                    style={{
                      background: 'rgba(255,255,255,0.03)',
                      border: '1px solid rgba(255,255,255,0.08)',
                      borderRadius: '4px',
                      color: '#e7f0ea',
                    }}
                  />
                </div>
              </div>

              {/* Position info */}
              <div className="mt-4 pt-3" style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                <div className="text-[10px] font-mono" style={{ color: '#444' }}>
                  位置: ({Math.round(selectedNode.position.x)}, {Math.round(selectedNode.position.y)})
                </div>
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center h-full p-6 text-center">
              <div className="w-12 h-12 flex items-center justify-center rounded-xl mb-3" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.06)' }}>
                <Plus className="w-5 h-5" style={{ color: '#5e6a63' }} />
              </div>
              <div className="text-[12px] font-mono mb-1" style={{ color: '#9aa8a0' }}>点击节点查看设置</div>
              <div className="text-[10px] font-mono" style={{ color: '#5e6a63' }}>或从左侧面板拖入新节点</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
