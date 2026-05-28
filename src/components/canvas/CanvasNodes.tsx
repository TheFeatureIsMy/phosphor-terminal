import { Handle, Position, type NodeTypes, type Node, type NodeProps } from '@xyflow/react'
import {
  Database, BarChart3, GitBranch, Zap, TrendingUp, Newspaper,
  Globe, Activity, Brain, Shield, Bell, Gauge, LineChart,
  ArrowUpDown, Target, AlertTriangle, Cpu
} from 'lucide-react'

/* ==================== Node Category Colors ==================== */
const COLORS = {
  dataSource: { border: 'rgba(125,183,255,0.25)', bg: 'rgba(125,183,255,0.04)', accent: '#7db7ff', handle: '#7db7ff' },
  indicator: { border: 'rgba(140,255,184,0.25)', bg: 'rgba(140,255,184,0.04)', accent: '#8cffb8', handle: '#8cffb8' },
  logicGate: { border: 'rgba(232,184,109,0.25)', bg: 'rgba(232,184,109,0.04)', accent: '#e8b86d', handle: '#e8b86d' },
  executor: { border: 'rgba(52,211,153,0.25)', bg: 'rgba(52,211,153,0.04)', accent: '#34d399', handle: '#34d399' },
  ai: { border: 'rgba(168,85,247,0.25)', bg: 'rgba(168,85,247,0.04)', accent: '#a855f7', handle: '#a855f7' },
  risk: { border: 'rgba(255,107,107,0.25)', bg: 'rgba(255,107,107,0.04)', accent: '#ff6b6b', handle: '#ff6b6b' },
}

/* ==================== Base Node Wrapper ==================== */
function BaseNode({
  type, icon: Icon, label, children, selected,
}: {
  type: keyof typeof COLORS
  icon: React.ElementType
  label: string
  children: React.ReactNode
  selected?: boolean
}) {
  const c = COLORS[type]
  return (
    <div
      className="relative group"
      style={{
        background: c.bg,
        border: `1px solid ${selected ? c.accent : c.border}`,
        borderRadius: '8px',
        padding: '10px 14px',
        minWidth: '180px',
        maxWidth: '240px',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        boxShadow: selected ? `0 0 16px ${c.accent}20, 0 2px 8px rgba(0,0,0,0.3)` : '0 2px 8px rgba(0,0,0,0.2)',
        transition: 'border-color 0.15s ease, box-shadow 0.15s ease',
      }}
    >
      {/* Top accent line */}
      <div className="absolute top-0 left-3 right-3 h-px" style={{ background: `linear-gradient(90deg, transparent, ${c.accent}40, transparent)` }} />

      {/* Header */}
      <div className="flex items-center gap-2 mb-2">
        <div className="w-5 h-5 flex items-center justify-center rounded" style={{ background: `${c.accent}15` }}>
          <Icon className="w-3 h-3" style={{ color: c.accent }} />
        </div>
        <span className="text-[10px] font-semibold tracking-wider uppercase" style={{ color: c.accent }}>
          {label}
        </span>
      </div>

      {/* Content */}
      <div className="space-y-1">
        {children}
      </div>
    </div>
  )
}

/* ==================== DataSource Nodes ==================== */
export function DataSourceNode({ data, selected }: NodeProps<Node<{ label: string; source: string; detail?: string }>>) {
  return (
    <BaseNode type="dataSource" icon={Database} label="数据源" selected={selected}>
      <div className="text-[13px] font-medium font-mono" style={{ color: '#e7f0ea' }}>{data.label}</div>
      <div className="text-[11px] font-mono" style={{ color: '#666' }}>{data.source}</div>
      {data.detail && <div className="text-[10px] font-mono mt-1 px-2 py-0.5 rounded" style={{ background: 'rgba(125,183,255,0.06)', color: '#7db7ff' }}>{data.detail}</div>}
      <Handle type="source" position={Position.Right} style={{ background: COLORS.dataSource.handle, width: 8, height: 8, border: '2px solid #111' }} />
    </BaseNode>
  )
}

/* ==================== Indicator Nodes ==================== */
export function IndicatorNode({ data, selected }: NodeProps<Node<{ label: string; params: string; value?: string }>>) {
  return (
    <BaseNode type="indicator" icon={BarChart3} label="指标" selected={selected}>
      <Handle type="target" position={Position.Left} style={{ background: COLORS.indicator.handle, width: 8, height: 8, border: '2px solid #111' }} />
      <div className="text-[13px] font-medium font-mono" style={{ color: '#e7f0ea' }}>{data.label}</div>
      <div className="text-[11px] font-mono" style={{ color: '#666' }}>{data.params}</div>
      {data.value && (
        <div className="text-[12px] font-bold font-tabular mt-1" style={{ color: '#8cffb8' }}>{data.value}</div>
      )}
      <Handle type="source" position={Position.Right} style={{ background: COLORS.indicator.handle, width: 8, height: 8, border: '2px solid #111' }} />
    </BaseNode>
  )
}

/* ==================== LogicGate Nodes ==================== */
export function LogicGateNode({ data, selected }: NodeProps<Node<{ label: string; condition: string; operator?: string }>>) {
  return (
    <BaseNode type="logicGate" icon={GitBranch} label="逻辑门" selected={selected}>
      <Handle type="target" position={Position.Left} style={{ background: COLORS.logicGate.handle, width: 8, height: 8, border: '2px solid #111' }} />
      <div className="text-[13px] font-medium font-mono" style={{ color: '#e7f0ea' }}>{data.label}</div>
      <div className="text-[11px] font-mono px-2 py-1 rounded mt-1" style={{ background: 'rgba(232,184,109,0.06)', color: '#e8b86d', border: '1px solid rgba(232,184,109,0.12)' }}>
        {data.condition}
      </div>
      <Handle type="source" position={Position.Right} style={{ background: COLORS.logicGate.handle, width: 8, height: 8, border: '2px solid #111' }} />
    </BaseNode>
  )
}

/* ==================== Executor Nodes ==================== */
export function ExecutorNode({ data, selected }: NodeProps<Node<{ label: string; action: string; params?: string }>>) {
  return (
    <BaseNode type="executor" icon={Zap} label="执行器" selected={selected}>
      <Handle type="target" position={Position.Left} style={{ background: COLORS.executor.handle, width: 8, height: 8, border: '2px solid #111' }} />
      <div className="text-[13px] font-medium font-mono" style={{ color: '#e7f0ea' }}>{data.label}</div>
      <div className="text-[11px] font-mono" style={{ color: '#666' }}>{data.action}</div>
      {data.params && <div className="text-[10px] font-mono mt-1" style={{ color: '#5e6a63' }}>{data.params}</div>}
    </BaseNode>
  )
}

/* ==================== AI Nodes ==================== */
export function AINode({ data, selected }: NodeProps<Node<{ label: string; model: string; confidence?: number }>>) {
  return (
    <BaseNode type="ai" icon={Brain} label="AI 模型" selected={selected}>
      <Handle type="target" position={Position.Left} style={{ background: COLORS.ai.handle, width: 8, height: 8, border: '2px solid #111' }} />
      <div className="text-[13px] font-medium font-mono" style={{ color: '#e7f0ea' }}>{data.label}</div>
      <div className="text-[11px] font-mono" style={{ color: '#a855f7' }}>{data.model}</div>
      {data.confidence !== undefined && (
        <div className="flex items-center gap-2 mt-1">
          <div className="flex-1 h-1 overflow-hidden rounded" style={{ background: 'rgba(168,85,247,0.1)' }}>
            <div className="h-full rounded" style={{ width: `${data.confidence}%`, background: '#a855f7' }} />
          </div>
          <span className="text-[10px] font-tabular" style={{ color: '#a855f7' }}>{data.confidence}%</span>
        </div>
      )}
      <Handle type="source" position={Position.Right} style={{ background: COLORS.ai.handle, width: 8, height: 8, border: '2px solid #111' }} />
    </BaseNode>
  )
}

/* ==================== Risk Nodes ==================== */
export function RiskNode({ data, selected }: NodeProps<Node<{ label: string; rule: string; severity?: string }>>) {
  const severityColor = data.severity === 'critical' ? '#ff6b6b' : data.severity === 'high' ? '#f97316' : '#e8b86d'
  return (
    <BaseNode type="risk" icon={Shield} label="风控" selected={selected}>
      <Handle type="target" position={Position.Left} style={{ background: COLORS.risk.handle, width: 8, height: 8, border: '2px solid #111' }} />
      <div className="text-[13px] font-medium font-mono" style={{ color: '#e7f0ea' }}>{data.label}</div>
      <div className="text-[11px] font-mono" style={{ color: '#666' }}>{data.rule}</div>
      {data.severity && (
        <span className="inline-block text-[9px] font-mono px-1.5 py-0.5 mt-1 rounded" style={{ background: `${severityColor}15`, color: severityColor, border: `1px solid ${severityColor}30` }}>
          {data.severity.toUpperCase()}
        </span>
      )}
      <Handle type="source" position={Position.Right} style={{ background: COLORS.risk.handle, width: 8, height: 8, border: '2px solid #111' }} />
    </BaseNode>
  )
}

/* ==================== Node Types Export ==================== */
export const canvasNodeTypes: NodeTypes = {
  dataSource: DataSourceNode,
  indicator: IndicatorNode,
  logicGate: LogicGateNode,
  executor: ExecutorNode,
  ai: AINode,
  risk: RiskNode,
}

/* ==================== Node Palette Categories ==================== */
export interface PaletteItem {
  type: string
  label: string
  icon: React.ElementType
  color: string
  defaultData: Record<string, unknown>
}

export interface PaletteCategory {
  label: string
  items: PaletteItem[]
}

export const paletteCategories: PaletteCategory[] = [
  {
    label: '数据源',
    items: [
      { type: 'dataSource', label: 'K线数据', icon: LineChart, color: '#7db7ff', defaultData: { label: 'Binance K线', source: 'BTC/USDT 1h', detail: 'OHLCV' } },
      { type: 'dataSource', label: '订单簿', icon: ArrowUpDown, color: '#7db7ff', defaultData: { label: 'L2 深度', source: 'Orderbook', detail: 'Top 20' } },
      { type: 'dataSource', label: '新闻流', icon: Newspaper, color: '#7db7ff', defaultData: { label: 'CryptoPanic', source: 'News API', detail: '实时推送' } },
      { type: 'dataSource', label: '社交情绪', icon: Globe, color: '#7db7ff', defaultData: { label: 'Reddit/X', source: 'Social Sentiment', detail: 'VADER' } },
      { type: 'dataSource', label: '链上数据', icon: Activity, color: '#7db7ff', defaultData: { label: '鲸鱼追踪', source: 'On-chain', detail: '大额转账' } },
      { type: 'dataSource', label: '宏观指标', icon: Gauge, color: '#7db7ff', defaultData: { label: 'DXY/VIX', source: 'Macro', detail: 'yfinance' } },
      { type: 'dataSource', label: '资金费率', icon: TrendingUp, color: '#7db7ff', defaultData: { label: 'Funding Rate', source: 'Binance', detail: '8h 周期' } },
    ],
  },
  {
    label: '技术指标',
    items: [
      { type: 'indicator', label: 'RSI', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'RSI', params: 'period=14' } },
      { type: 'indicator', label: 'MACD', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'MACD', params: 'fast=12, slow=26, signal=9' } },
      { type: 'indicator', label: 'SMA', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'SMA', params: 'period=50' } },
      { type: 'indicator', label: 'EMA', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'EMA', params: 'period=21' } },
      { type: 'indicator', label: 'Bollinger', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'Bollinger Bands', params: 'period=20, std=2' } },
      { type: 'indicator', label: 'ATR', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'ATR', params: 'period=14' } },
      { type: 'indicator', label: 'OBV', icon: BarChart3, color: '#8cffb8', defaultData: { label: 'OBV', params: 'volume-based' } },
    ],
  },
  {
    label: 'AI 模型',
    items: [
      { type: 'ai', label: 'FinBERT', icon: Brain, color: '#a855f7', defaultData: { label: '情绪分析', model: 'FinBERT-Crypto', confidence: 78 } },
      { type: 'ai', label: 'SHAP', icon: Brain, color: '#a855f7', defaultData: { label: '特征归因', model: 'SHAP-LGBM', confidence: 85 } },
      { type: 'ai', label: 'FreqAI', icon: Cpu, color: '#a855f7', defaultData: { label: '增量学习', model: 'FreqAI-LSTM', confidence: 72 } },
    ],
  },
  {
    label: '逻辑门',
    items: [
      { type: 'logicGate', label: 'AND 门', icon: GitBranch, color: '#e8b86d', defaultData: { label: 'AND 条件', condition: 'A AND B' } },
      { type: 'logicGate', label: 'OR 门', icon: GitBranch, color: '#e8b86d', defaultData: { label: 'OR 条件', condition: 'A OR B' } },
      { type: 'logicGate', label: '阈值', icon: Target, color: '#e8b86d', defaultData: { label: '阈值判断', condition: 'value > threshold' } },
      { type: 'logicGate', label: '交叉', icon: GitBranch, color: '#e8b86d', defaultData: { label: '金叉/死叉', condition: 'MA_fast CROSS MA_slow' } },
    ],
  },
  {
    label: '执行器',
    items: [
      { type: 'executor', label: '市价买入', icon: Zap, color: '#34d399', defaultData: { label: '市价买入', action: 'BUY market' } },
      { type: 'executor', label: '市价卖出', icon: Zap, color: '#34d399', defaultData: { label: '市价卖出', action: 'SELL market' } },
      { type: 'executor', label: '限价单', icon: Zap, color: '#34d399', defaultData: { label: '限价买入', action: 'BUY limit', params: 'price = close * 0.99' } },
      { type: 'executor', label: '止损', icon: AlertTriangle, color: '#34d399', defaultData: { label: '止损卖出', action: 'STOP_LOSS', params: '-5%' } },
    ],
  },
  {
    label: '风控',
    items: [
      { type: 'risk', label: '止损保护', icon: Shield, color: '#ff6b6b', defaultData: { label: '止损保护', rule: '亏损 > 5% 触发', severity: 'critical' } },
      { type: 'risk', label: '仓位限制', icon: Shield, color: '#ff6b6b', defaultData: { label: '仓位限制', rule: '单仓 < 20%', severity: 'high' } },
      { type: 'risk', label: '频率限制', icon: Bell, color: '#ff6b6b', defaultData: { label: '交易频率', rule: '< 10次/小时', severity: 'medium' } },
    ],
  },
]

/* ==================== Default Canvas State ==================== */
export const defaultCanvasNodes = [
  { id: '1', type: 'dataSource', position: { x: 50, y: 120 }, data: { label: 'Binance K线', source: 'BTC/USDT 1h', detail: 'OHLCV' } },
  { id: '2', type: 'dataSource', position: { x: 50, y: 280 }, data: { label: 'CryptoPanic', source: 'News API', detail: '实时推送' } },
  { id: '3', type: 'indicator', position: { x: 320, y: 60 }, data: { label: 'RSI', params: 'period=14', value: '32.5' } },
  { id: '4', type: 'indicator', position: { x: 320, y: 200 }, data: { label: 'SMA', params: 'period=50', value: '$67,234' } },
  { id: '5', type: 'ai', position: { x: 320, y: 340 }, data: { label: '情绪分析', model: 'FinBERT-Crypto', confidence: 78 } },
  { id: '6', type: 'logicGate', position: { x: 580, y: 120 }, data: { label: '买入条件', condition: 'RSI < 30 AND close > SMA' } },
  { id: '7', type: 'logicGate', position: { x: 580, y: 300 }, data: { label: '情绪过滤', condition: 'sentiment > 0.3' } },
  { id: '8', type: 'risk', position: { x: 820, y: 60 }, data: { label: '止损保护', rule: '亏损 > 5%', severity: 'critical' } },
  { id: '9', type: 'executor', position: { x: 820, y: 200 }, data: { label: '市价买入', action: 'BUY BTC/USDT' } },
]

export const defaultCanvasEdges = [
  { id: 'e1-3', source: '1', target: '3', animated: true, style: { stroke: '#8cffb8' } },
  { id: 'e1-4', source: '1', target: '4', animated: true, style: { stroke: '#8cffb8' } },
  { id: 'e2-5', source: '2', target: '5', animated: true, style: { stroke: '#a855f7' } },
  { id: 'e3-6', source: '3', target: '6', style: { stroke: '#7db7ff' } },
  { id: 'e4-6', source: '4', target: '6', style: { stroke: '#7db7ff' } },
  { id: 'e5-7', source: '5', target: '7', style: { stroke: '#a855f7' } },
  { id: 'e6-9', source: '6', target: '9', animated: true, style: { stroke: '#e8b86d' } },
  { id: 'e7-9', source: '7', target: '9', style: { stroke: '#e8b86d' } },
  { id: 'e6-8', source: '6', target: '8', style: { stroke: '#ff6b6b' } },
]

export function getDefaultNodeData(type: string) {
  for (const cat of paletteCategories) {
    const item = cat.items.find(i => i.type === type)
    if (item) return { ...item.defaultData }
  }
  return {}
}
