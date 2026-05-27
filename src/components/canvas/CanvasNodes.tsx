import { Handle, Position, type NodeTypes } from '@xyflow/react'
import { Database, BarChart3, GitBranch, Zap } from 'lucide-react'

export function DataSourceNode({ data }: { data: { label: string; source: string } }) {
  return (
    <div style={{ background: '#111', border: '1px solid rgba(0,194,255,0.3)', borderRadius: '2px', padding: '12px', minWidth: '160px' }}>
      <div className="flex items-center gap-1.5 mb-1">
        <Database className="w-3.5 h-3.5 text-info" />
        <span className="text-[10px] font-semibold text-info tracking-wider uppercase">数据源</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted mt-0.5">{data.source}</div>
      <Handle type="source" position={Position.Right} className="!bg-info !w-2 !h-2" />
    </div>
  )
}

export function IndicatorNode({ data }: { data: { label: string; params: string } }) {
  return (
    <div style={{ background: '#111', border: '1px solid rgba(0,255,157,0.3)', borderRadius: '2px', padding: '12px', minWidth: '160px' }}>
      <Handle type="target" position={Position.Left} className="!bg-primary !w-2 !h-2" />
      <div className="flex items-center gap-1.5 mb-1">
        <BarChart3 className="w-3.5 h-3.5 text-primary" />
        <span className="text-[10px] font-semibold text-primary tracking-wider uppercase">指标</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted mt-0.5">{data.params}</div>
      <Handle type="source" position={Position.Right} className="!bg-primary !w-2 !h-2" />
    </div>
  )
}

export function LogicGateNode({ data }: { data: { label: string; condition: string } }) {
  return (
    <div style={{ background: '#111', border: '1px solid rgba(255,184,0,0.3)', borderRadius: '2px', padding: '12px', minWidth: '160px' }}>
      <Handle type="target" position={Position.Left} className="!bg-accent !w-2 !h-2" />
      <div className="flex items-center gap-1.5 mb-1">
        <GitBranch className="w-3.5 h-3.5 text-accent" />
        <span className="text-[10px] font-semibold text-accent tracking-wider uppercase">逻辑门</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted mt-0.5">{data.condition}</div>
      <Handle type="source" position={Position.Right} className="!bg-accent !w-2 !h-2" />
    </div>
  )
}

export function ExecutorNode({ data }: { data: { label: string; action: string } }) {
  return (
    <div style={{ background: '#111', border: '1px solid rgba(0,255,157,0.3)', borderRadius: '2px', padding: '12px', minWidth: '160px' }}>
      <Handle type="target" position={Position.Left} className="!bg-success !w-2 !h-2" />
      <div className="flex items-center gap-1.5 mb-1">
        <Zap className="w-3.5 h-3.5 text-success" />
        <span className="text-[10px] font-semibold text-success tracking-wider uppercase">执行器</span>
      </div>
      <div className="text-[13px] font-medium">{data.label}</div>
      <div className="text-[11px] text-text-muted mt-0.5">{data.action}</div>
    </div>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export const canvasNodeTypes: NodeTypes = {
  dataSource: DataSourceNode,
  indicator: IndicatorNode,
  logicGate: LogicGateNode,
  executor: ExecutorNode,
}

// eslint-disable-next-line react-refresh/only-export-components
export const defaultCanvasNodes = [
  { id: '1', type: 'dataSource', position: { x: 50, y: 100 }, data: { label: 'Binance K线', source: 'BTC/USDT 1h' } },
  { id: '2', type: 'indicator', position: { x: 300, y: 50 }, data: { label: 'RSI', params: 'period=14' } },
  { id: '3', type: 'indicator', position: { x: 300, y: 180 }, data: { label: 'SMA', params: 'period=50' } },
  { id: '4', type: 'logicGate', position: { x: 550, y: 100 }, data: { label: '买入条件', condition: 'RSI < 30 AND close > SMA' } },
  { id: '5', type: 'executor', position: { x: 800, y: 100 }, data: { label: '市价买入', action: 'BUY BTC/USDT' } },
]

// eslint-disable-next-line react-refresh/only-export-components
export const defaultCanvasEdges = [
  { id: 'e1-2', source: '1', target: '2', animated: true, style: { stroke: '#00ff9d' } },
  { id: 'e1-3', source: '1', target: '3', animated: true, style: { stroke: '#00ff9d' } },
  { id: 'e2-4', source: '2', target: '4', style: { stroke: '#00c2ff' } },
  { id: 'e3-4', source: '3', target: '4', style: { stroke: '#00c2ff' } },
  { id: 'e4-5', source: '4', target: '5', animated: true, style: { stroke: '#00ff9d' } },
]

// eslint-disable-next-line react-refresh/only-export-components
export function getDefaultNodeData(type: string) {
  switch (type) {
    case 'dataSource': return { source: '数据源' }
    case 'indicator': return { params: 'period=14' }
    case 'logicGate': return { condition: '条件表达式' }
    case 'executor': return { action: '执行动作' }
    default: return {}
  }
}
