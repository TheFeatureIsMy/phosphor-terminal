import { describe, it, expect } from 'vitest'
import { dslToGraph, resetIdCounter } from './dslToGraph'
import type { RulePackageDSL } from '../types'

function makeDSL(overrides?: Partial<RulePackageDSL>): RulePackageDSL {
  return {
    schema_version: '2.5',
    timeframe: '1h',
    symbols: ['BTC/USDT'],
    entry: {
      logic: 'AND',
      rules: [{ type: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '<', value: 30 }],
    },
    exit: {
      logic: 'OR',
      rules: [{ type: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '>', value: 70 }],
    },
    filters: [],
    position_sizing: { type: 'fixed_pct', position_pct: 0.02 },
    risk: { stoploss: -0.05, max_open_trades: 3 },
    metadata: {},
    ...overrides,
  }
}

describe('dslToGraph', () => {
  it('creates correct number of nodes for basic DSL', () => {
    resetIdCounter()
    const { nodes, edges } = dslToGraph(makeDSL())
    // signalInput + executionOutput + 1 entry + 1 exit + positionSizing + riskPolicy = 6
    expect(nodes).toHaveLength(6)
    expect(nodes.filter(n => n.type === 'signalInput')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'executionOutput')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'indicatorCondition')).toHaveLength(2)
    expect(nodes.filter(n => n.type === 'positionSizing')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'riskPolicy')).toHaveLength(1)
  })

  it('creates correct edges', () => {
    resetIdCounter()
    const { edges } = dslToGraph(makeDSL())
    // signal→entry, entry→output(entry), signal→exit, exit→output(exit), sizing→output, risk→output = 6
    expect(edges.length).toBeGreaterThanOrEqual(6)

    const entryEdges = edges.filter(e => e.targetHandle === 'entryConditions')
    const exitEdges = edges.filter(e => e.targetHandle === 'exitConditions')
    expect(entryEdges).toHaveLength(1)
    expect(exitEdges).toHaveLength(1)
  })

  it('handles multiple entry rules', () => {
    resetIdCounter()
    const dsl = makeDSL({
      entry: {
        logic: 'AND',
        rules: [
          { type: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '<', value: 30 },
          { type: 'indicator_threshold', indicator: 'ema', params: { period: 20 }, operator: '>', value: 50000 },
        ],
      },
    })
    const { nodes, edges } = dslToGraph(dsl)
    expect(nodes.filter(n => n.type === 'indicatorCondition')).toHaveLength(3) // 2 entry + 1 exit
    const entryEdges = edges.filter(e => e.targetHandle === 'entryConditions')
    expect(entryEdges).toHaveLength(2)
  })

  it('handles filters', () => {
    resetIdCounter()
    const dsl = makeDSL({
      filters: [
        { type: 'volume_filter', indicator: 'volume', operator: '>', value: 1000000 },
        { type: 'cooldown_filter', candles: 5 },
      ],
    })
    const { nodes, edges } = dslToGraph(dsl)
    expect(nodes.filter(n => n.type === 'filter')).toHaveLength(2)
    const filterEdges = edges.filter(e => e.targetHandle === 'filters')
    expect(filterEdges).toHaveLength(2)
  })

  it('preserves position_sizing data', () => {
    resetIdCounter()
    const { nodes } = dslToGraph(makeDSL({ position_sizing: { type: 'fixed_pct', position_pct: 0.05 } }))
    const sizing = nodes.find(n => n.type === 'positionSizing')
    expect(sizing).toBeDefined()
    expect((sizing!.data as Record<string, unknown>).positionPct).toBe(0.05)
  })

  it('preserves risk data with trailing stop', () => {
    resetIdCounter()
    const { nodes } = dslToGraph(makeDSL({
      risk: { stoploss: -0.03, max_open_trades: 5, trailing_stop: true, trailing_stop_positive: 0.01 },
    }))
    const risk = nodes.find(n => n.type === 'riskPolicy')
    expect(risk).toBeDefined()
    const data = risk!.data as Record<string, unknown>
    expect(data.stoploss).toBe(-0.03)
    expect(data.maxOpenTrades).toBe(5)
    expect(data.trailingStop).toBe(true)
    expect(data.trailingStopPositive).toBe(0.01)
  })

  it('preserves entry/exit logic', () => {
    resetIdCounter()
    const dsl = makeDSL()
    dsl.entry.logic = 'OR'
    dsl.exit.logic = 'AND'
    const { nodes } = dslToGraph(dsl)
    const output = nodes.find(n => n.type === 'executionOutput')
    const data = output!.data as Record<string, unknown>
    expect(data.entryLogic).toBe('OR')
    expect(data.exitLogic).toBe('AND')
  })

  it('handles indicator_cross rules', () => {
    resetIdCounter()
    const dsl = makeDSL({
      entry: {
        logic: 'AND',
        rules: [{
          type: 'indicator_cross', indicator: 'ema', params: { period: 5 },
          cross_indicator: 'sma', cross_params: { period: 20 }, direction: 'crosses_above',
        }],
      },
    })
    const { nodes } = dslToGraph(dsl)
    const condNodes = nodes.filter(n => n.type === 'indicatorCondition')
    const entryNode = condNodes[0]
    const data = entryNode.data as Record<string, unknown>
    expect(data.ruleType).toBe('indicator_cross')
    expect(data.crossIndicator).toBe('sma')
    expect(data.direction).toBe('crosses_above')
  })
})
