import { Position, useReactFlow, type NodeProps } from '@xyflow/react'
import type { DSLError } from '../types'
import { NodeShell } from './NodeShell'
import { NodeNumber, NodeSelect, NodeToggle } from './EditableControls'

/**
 * 平台原生节点：熔断保护、结构信号、AI 成长。
 * 把 AlphaLoop 自身的风控/结构/成长能力暴露为策略可用节点。
 */

/* ── 熔断保护节点(风控中心熔断状态) ─────────────────────────── */
export function CircuitBreakerNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const blockWhenTripped = (data.blockWhenTripped as boolean) ?? true
  const respectKillSwitch = (data.respectKillSwitch as boolean) ?? true

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="circuitBreaker"
      title="熔断保护"
      dotColor="var(--pa-node-circuit, #ff4d6d)"
      rows={[
        {
          k: '熔断时拦截', edit: true,
          v: <NodeToggle checked={blockWhenTripped} ariaLabel="熔断时拦截新开仓" onChange={v => set({ blockWhenTripped: v })} />,
        },
        {
          k: '尊重 Kill Switch', edit: true,
          v: <NodeToggle checked={respectKillSwitch} ariaLabel="尊重 Kill Switch" onChange={v => set({ respectKillSwitch: v })} />,
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

/* ── 结构信号节点(市场结构/操纵雷达信号) ─────────────────────── */
const STRUCTURE_TYPES = [
  { value: 'liquidity_pool', label: '流动性池' },
  { value: 'fvg', label: 'FVG 缺口' },
  { value: 'order_block', label: '订单块' },
  { value: 'bos_choch', label: 'BOS/CHoCH' },
]

export function StructureSignalNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const structureType = (data.structureType as string) ?? 'liquidity_pool'
  const minScore = (data.minScore as number) ?? 70
  const requireFresh = (data.requireFresh as boolean) ?? true

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="structureSignal"
      title="结构信号"
      dotColor="var(--pa-node-structure, #14f195)"
      rows={[
        {
          k: '结构类型', edit: true,
          v: <NodeSelect value={structureType} ariaLabel="结构类型" options={STRUCTURE_TYPES} onChange={v => set({ structureType: v })} />,
        },
        {
          k: '最低强度', edit: true,
          v: <NodeNumber value={minScore} step={5} ariaLabel="最低结构强度分" onChange={v => set({ minScore: v })} />,
        },
        {
          k: '需新鲜', edit: true,
          v: <NodeToggle checked={requireFresh} ariaLabel="要求信号新鲜" onChange={v => set({ requireFresh: v })} />,
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

/* ── AI 成长节点(复盘/成长引擎信号) ──────────────────────────── */
const GROWTH_MODES = [
  { value: 'winning_pattern', label: '盈利形态' },
  { value: 'avoid_failure', label: '避开失败模式' },
  { value: 'candidate_boost', label: '候选策略加权' },
]

export function AIGrowthNode({ id, data, selected }: NodeProps) {
  const { updateNodeData } = useReactFlow()
  const errors = (data.validationErrors ?? []) as DSLError[]
  const invalid = errors.some(e => e.severity === 'error')
  const mode = (data.mode as string) ?? 'winning_pattern'
  const minConfidence = (data.minConfidence as number) ?? 0.6

  const set = (p: Record<string, unknown>) => updateNodeData(id, p)

  return (
    <NodeShell
      type="aiGrowth"
      title="AI 成长"
      dotColor="var(--pa-node-aigrowth, #b4ff3d)"
      rows={[
        {
          k: '模式', edit: true,
          v: <NodeSelect value={mode} ariaLabel="成长模式" options={GROWTH_MODES} onChange={v => set({ mode: v })} />,
        },
        {
          k: '最低置信', edit: true,
          v: <NodeNumber value={+(minConfidence * 100).toFixed(0)} step={5} ariaLabel="最低置信度%" onChange={v => set({ minConfidence: v / 100 })} />,
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