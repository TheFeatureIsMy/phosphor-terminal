import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'
import { NodeNumber, NodeSelect, NodeText, NodeToggle } from './EditableControls'

/**
 * 另类数据节点：新闻/情绪、热点、资金费率、链上。
 * 底层映射为 DSL filter 规则（sentiment_filter / news_heat_filter /
 * funding_filter / onchain_filter），但提供领域化的富编辑 UI。
 */

const SENTIMENT_SOURCES = [
  { value: 'news', label: '新闻' },
  { value: 'social', label: '社交' },
  { value: 'combined', label: '综合' },
]

/* ── 情绪 / 新闻节点 ─────────────────────────────────────────── */
export function SentimentNewsNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const source = (data.source as string) ?? 'combined'
  const minSentiment = (data.minSentiment as number) ?? -1
  const maxSentiment = (data.maxSentiment as number) ?? 1
  const requirePositive = (data.requirePositive as boolean) ?? false

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="sentimentNews"
      title="情绪 / 新闻"
      dotColor="var(--pa-node-sentiment, #8b7cff)"
      rows={[
        {
          k: '来源', edit: true,
          v: <NodeSelect value={source} ariaLabel="情绪来源" options={SENTIMENT_SOURCES} onChange={v => set({ source: v })} />,
        },
        {
          k: '最低情绪', edit: true,
          v: <NodeNumber value={minSentiment} step={0.1} ariaLabel="最低情绪分" onChange={v => set({ minSentiment: v })} />,
        },
        {
          k: '仅正面', edit: true,
          v: <NodeToggle checked={requirePositive} ariaLabel="仅正面情绪" onChange={v => set({ requirePositive: v })} />,
        },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'filtered' },
      ]}
    />
  )
}

/* ── 热点 / 趋势节点 ─────────────────────────────────────────── */
export function TrendingNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const minHeat = (data.minHeatScore as number) ?? 50
  const keywords = (data.keywords as string[]) ?? []

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="trending"
      title="热点 / 趋势"
      dotColor="var(--pa-node-trending, #ff8a4c)"
      rows={[
        {
          k: '最低热度', edit: true,
          v: <NodeNumber value={minHeat} step={5} ariaLabel="最低热度分" onChange={v => set({ minHeatScore: v })} />,
        },
        {
          k: '关键词', edit: true,
          v: (
            <NodeText
              value={keywords.join(',')}
              placeholder="AI,ETF,减半"
              ariaLabel="热点关键词"
              onChange={v => set({ keywords: v.split(',').map(s => s.trim()).filter(Boolean) })}
            />
          ),
        },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'filtered' },
      ]}
    />
  )
}

/* ── 资金费率节点 ────────────────────────────────────────────── */
export function FundingNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const maxFunding = (data.maxFundingRate as number) ?? 0.0001
  const avoidCrowded = (data.avoidCrowded as boolean) ?? true

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="funding"
      title="资金费率"
      dotColor="var(--pa-node-funding, #4cc9f0)"
      rows={[
        {
          k: '最大费率', edit: true,
          v: <NodeNumber value={+(maxFunding * 10000).toFixed(1)} step={0.5} ariaLabel="最大资金费率(bps)" onChange={v => set({ maxFundingRate: v / 10000 })} />,
        },
        {
          k: '避拥挤', edit: true,
          v: <NodeToggle checked={avoidCrowded} ariaLabel="避开拥挤交易" onChange={v => set({ avoidCrowded: v })} />,
        },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'filtered' },
      ]}
    />
  )
}

/* ── 链上 / 巨鲸节点 ─────────────────────────────────────────── */
export function OnchainNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const whaleThreshold = (data.whaleThreshold as number) ?? 1000000
  const requireInflow = (data.requireInflow as boolean) ?? false

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="onchain"
      title="链上 / 巨鲸"
      dotColor="var(--pa-node-onchain, #f7931a)"
      rows={[
        {
          k: '巨鲸阈值$', edit: true,
          v: <NodeNumber value={whaleThreshold} step={100000} ariaLabel="巨鲸单笔阈值(美元)" onChange={v => set({ whaleThreshold: v })} />,
        },
        {
          k: '需净流入', edit: true,
          v: <NodeToggle checked={requireInflow} ariaLabel="要求交易所净流入" onChange={v => set({ requireInflow: v })} />,
        },
      ]}
      selected={selected}
      invalid={invalid}
      errMessage={invalid ? errors[0]?.code : undefined}
      ports={[
        { type: 'target', position: Position.Left, id: 'signal' },
        { type: 'source', position: Position.Right, id: 'filtered' },
      ]}
    />
  )
}