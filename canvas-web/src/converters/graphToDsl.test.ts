import { describe, it, expect } from 'vitest'
import { graphToDsl } from './graphToDsl'
import type { Node, Edge } from '@xyflow/react'

function makeSignal(id = 's1'): Node {
  return { id, type: 'signalInput', position: { x: 0, y: 0 }, data: { timeframe: '1h', symbols: ['BTC/USDT'] } }
}

function makeCondition(id: string, indicator = 'rsi', op = '<', value = 30): Node {
  return {
    id, type: 'indicatorCondition', position: { x: 300, y: 0 },
    data: { ruleType: 'indicator_threshold', indicator, params: { period: 14 }, operator: op, value },
  }
}

function makeFilter(id: string): Node {
  return {
    id, type: 'filter', position: { x: 500, y: 0 },
    data: { ruleType: 'volume_filter', indicator: 'volume', operator: '>', value: 1000000 },
  }
}

function makeSizing(id = 'ps1'): Node {
  return { id, type: 'positionSizing', position: { x: 500, y: 200 }, data: { type: 'fixed_pct', positionPct: 0.02 } }
}

function makeRisk(id = 'rk1'): Node {
  return { id, type: 'riskPolicy', position: { x: 500, y: 300 }, data: { stoploss: -0.05, maxOpenTrades: 3 } }
}

function makeOutput(id = 'out1'): Node {
  return { id, type: 'executionOutput', position: { x: 800, y: 0 }, data: { entryLogic: 'AND', exitLogic: 'OR', schemaVersion: '2.5' } }
}

function edge(source: string, target: string, sourceHandle: string, targetHandle: string): Edge {
  return { id: `e_${source}_${target}_${targetHandle}`, source, target, sourceHandle, targetHandle }
}

function fullGraph() {
  const nodes: Node[] = [
    makeSignal(), makeCondition('c1', 'rsi', '<', 30), makeCondition('c2', 'rsi', '>', 70),
    makeSizing(), makeRisk(), makeOutput(),
  ]
  const edges: Edge[] = [
    edge('s1', 'c1', 'signal', 'signal'),
    edge('s1', 'c2', 'signal', 'signal'),
    edge('c1', 'out1', 'condition', 'entryConditions'),
    edge('c2', 'out1', 'condition', 'exitConditions'),
    edge('ps1', 'out1', 'sizing', 'sizing'),
    edge('rk1', 'out1', 'risk', 'risk'),
  ]
  return { nodes, edges }
}

describe('graphToDsl', () => {
  it('converts a complete graph to valid DSL', () => {
    const { nodes, edges } = fullGraph()
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    expect(result.dsl).not.toBeNull()
    expect(result.dsl!.schema_version).toBe('2.5')
    expect(result.dsl!.timeframe).toBe('1h')
    expect(result.dsl!.symbols).toEqual(['BTC/USDT'])
    expect(result.dsl!.entry.logic).toBe('AND')
    expect(result.dsl!.entry.rules).toHaveLength(1)
    expect(result.dsl!.exit.logic).toBe('OR')
    expect(result.dsl!.exit.rules).toHaveLength(1)
    expect(result.dsl!.position_sizing.position_pct).toBe(0.02)
    expect(result.dsl!.risk.stoploss).toBe(-0.05)
    expect(result.dsl!.risk.max_open_trades).toBe(3)
  })

  it('errors when no SignalInputNode', () => {
    const nodes = [makeCondition('c1'), makeOutput()]
    const edges: Edge[] = [edge('c1', 'out1', 'condition', 'entryConditions')]
    const result = graphToDsl(nodes, edges)
    expect(result.dsl).toBeNull()
    expect(result.errors.some(e => e.message.includes('信号输入'))).toBe(true)
  })

  it('errors when no ExecutionOutputNode', () => {
    const nodes = [makeSignal(), makeCondition('c1')]
    const result = graphToDsl(nodes, [])
    expect(result.dsl).toBeNull()
    expect(result.errors.some(e => e.message.includes('执行输出'))).toBe(true)
  })

  it('errors when no entry conditions connected', () => {
    const nodes = [makeSignal(), makeCondition('c1'), makeOutput()]
    const edges = [edge('c1', 'out1', 'condition', 'exitConditions')]
    const result = graphToDsl(nodes, edges)
    expect(result.dsl).toBeNull()
    expect(result.errors.some(e => e.message.includes('入场条件'))).toBe(true)
  })

  it('errors when no exit conditions connected', () => {
    const nodes = [makeSignal(), makeCondition('c1'), makeOutput()]
    const edges = [edge('c1', 'out1', 'condition', 'entryConditions')]
    const result = graphToDsl(nodes, edges)
    expect(result.dsl).toBeNull()
    expect(result.errors.some(e => e.message.includes('出场条件'))).toBe(true)
  })

  it('collects multiple entry rules', () => {
    const nodes = [
      makeSignal(), makeCondition('c1', 'rsi', '<', 30), makeCondition('c2', 'ema', '>', 100),
      makeCondition('c3', 'rsi', '>', 70), makeOutput(),
    ]
    const edges = [
      edge('c1', 'out1', 'condition', 'entryConditions'),
      edge('c2', 'out1', 'condition', 'entryConditions'),
      edge('c3', 'out1', 'condition', 'exitConditions'),
    ]
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    expect(result.dsl!.entry.rules).toHaveLength(2)
  })

  it('collects filters', () => {
    const { nodes, edges } = fullGraph()
    nodes.push(makeFilter('f1'))
    edges.push(edge('s1', 'f1', 'signal', 'signal'))
    edges.push(edge('f1', 'out1', 'filtered', 'filters'))
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    expect(result.dsl!.filters).toHaveLength(1)
    expect(result.dsl!.filters[0].type).toBe('volume_filter')
  })

  it('warns about disconnected nodes', () => {
    const { nodes, edges } = fullGraph()
    nodes.push(makeCondition('orphan', 'macd', '>', 0))
    const result = graphToDsl(nodes, edges)
    expect(result.warnings.some(w => w.nodeId === 'orphan')).toBe(true)
  })

  it('converts indicator_cross rule correctly', () => {
    const nodes = [
      makeSignal(),
      {
        id: 'cross1', type: 'indicatorCondition', position: { x: 300, y: 0 },
        data: {
          ruleType: 'indicator_cross', indicator: 'ema', params: { period: 5 },
          operator: 'crosses_above', crossIndicator: 'sma', crossParams: { period: 20 },
          direction: 'crosses_above',
        },
      } as Node,
      makeCondition('c2', 'rsi', '>', 70),
      makeOutput(),
    ]
    const edges = [
      edge('cross1', 'out1', 'condition', 'entryConditions'),
      edge('c2', 'out1', 'condition', 'exitConditions'),
    ]
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    expect(result.dsl!.entry.rules[0].type).toBe('indicator_cross')
    expect(result.dsl!.entry.rules[0].cross_indicator).toBe('sma')
  })
})
