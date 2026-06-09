import { describe, it, expect } from 'vitest'
import { dslToGraph, resetIdCounter } from './dslToGraph'
import type { RulePackageDSL, RulePackageDSLV3 } from '../types'

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

function makeDSLV3(overrides?: Partial<RulePackageDSLV3>): RulePackageDSLV3 {
  return {
    schema_version: '3.0',
    strategy: { id: 'strat_1', name: 'Test Strategy', symbol: 'BTC/USDT', timeframe: '1h', mode: 'auto' },
    entry_logic: {
      logic: 'AND',
      rules: [{ type: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '<', value: 30 }],
    },
    exit_logic: {
      logic: 'OR',
      rules: [{ type: 'indicator_threshold', indicator: 'rsi', params: { period: 14 }, operator: '>', value: 70 }],
    },
    filters: [],
    stop_policy: { mode: 'fixed', fallback_stop_pct: 0.05 },
    position_policy: { risk_per_trade: 0.02, max_position_pct: 0.1 },
    account_risk_policy: { max_daily_loss: 0.03, max_weekly_loss: 0.08, max_consecutive_losses: 4, kill_switch_enabled: true },
    disconnect_protection: { enabled: true, max_snapshot_miss_ticks: 3, hard_disconnect_timeout_ms: 30000, fallback_stop_pct: 0.05, emergency_action: 'flatten' },
    metadata: {},
    ...overrides,
  }
}

describe('dslToGraph v2.5', () => {
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

describe('dslToGraph v3.0', () => {
  it('creates correct nodes for v3.0 DSL', () => {
    resetIdCounter()
    const { nodes } = dslToGraph(makeDSLV3())
    // signalInput + executionOutput + 1 entry + 1 exit + positionSizing + riskPolicy + accountRisk = 7
    expect(nodes.filter(n => n.type === 'signalInput')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'executionOutput')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'indicatorCondition')).toHaveLength(2)
    expect(nodes.filter(n => n.type === 'positionSizing')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'riskPolicy')).toHaveLength(1)
    expect(nodes.filter(n => n.type === 'accountRisk')).toHaveLength(1)
  })

  it('preserves strategy fields in signal node', () => {
    resetIdCounter()
    const dsl = makeDSLV3()
    dsl.strategy.symbol = 'ETH/USDT'
    dsl.strategy.timeframe = '4h'
    const { nodes } = dslToGraph(dsl)
    const signal = nodes.find(n => n.type === 'signalInput')!
    const data = signal.data as Record<string, unknown>
    expect(data.timeframe).toBe('4h')
    expect(data.symbols).toEqual(['ETH/USDT'])
  })

  it('preserves account_risk_policy data', () => {
    resetIdCounter()
    const dsl = makeDSLV3()
    dsl.account_risk_policy = { max_daily_loss: 0.05, max_weekly_loss: 0.15, max_consecutive_losses: 6, kill_switch_enabled: false }
    const { nodes } = dslToGraph(dsl)
    const arNode = nodes.find(n => n.type === 'accountRisk')!
    const data = arNode.data as Record<string, unknown>
    expect(data.maxDailyLoss).toBe(0.05)
    expect(data.maxWeeklyLoss).toBe(0.15)
    expect(data.maxConsecutiveLosses).toBe(6)
    expect(data.killSwitchEnabled).toBe(false)
  })

  it('creates MTF Guard nodes and edges', () => {
    resetIdCounter()
    const dsl = makeDSLV3({
      mtf_guards: [{
        guard_id: 'guard_1',
        name: 'OB Guard 4h→1h',
        fast_timeframe: '1h',
        slow_timeframe: '4h',
        source_node: 'entry_ob',
        target_node: 'exec_out',
        structure_type: 'order_block',
        shadow_window: { mode: 'strict', max_fast_candles: 12, allow_low_tf_touch: false, allow_low_tf_update_filled_ratio: false },
        violation_policy: { temporary_violation: 'hold', reclaim_pending: 'reduce', confirmed_reclaim: 'resume', confirmed_break: 'exit' },
      }],
    })
    const { nodes, edges } = dslToGraph(dsl)
    const guardNodes = nodes.filter(n => n.type === 'mtfGuard')
    expect(guardNodes).toHaveLength(1)

    const guardData = guardNodes[0].data as Record<string, unknown>
    expect(guardData.guardId).toBe('guard_1')
    expect(guardData.fastTimeframe).toBe('1h')
    expect(guardData.slowTimeframe).toBe('4h')
    expect(guardData.structureType).toBe('order_block')

    // Should have mtfGuard typed edges
    const guardEdges = edges.filter(e => e.type === 'mtfGuard')
    expect(guardEdges).toHaveLength(1)
    const edgeData = guardEdges[0].data as Record<string, unknown>
    expect(edgeData.guardId).toBe('guard_1')
    expect(edgeData.guardState).toBe('watching')
  })

  it('creates structure defense node when stop_policy uses structure', () => {
    resetIdCounter()
    const dsl = makeDSLV3()
    dsl.stop_policy.mode = 'structure_based'
    dsl.stop_policy.priority = ['order_block', 'fvg']
    const { nodes } = dslToGraph(dsl)
    const sdNodes = nodes.filter(n => n.type === 'structureDefense')
    expect(sdNodes).toHaveLength(1)
    const data = sdNodes[0].data as Record<string, unknown>
    expect(data.structures).toEqual(['order_block', 'fvg'])
  })

  it('sets schemaVersion to 3.0 in execution output', () => {
    resetIdCounter()
    const { nodes } = dslToGraph(makeDSLV3())
    const output = nodes.find(n => n.type === 'executionOutput')!
    expect((output.data as Record<string, unknown>).schemaVersion).toBe('3.0')
  })
})
