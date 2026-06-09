import { describe, it, expect } from 'vitest'
import { graphToDsl } from './graphToDsl'
import { dslToGraph, resetIdCounter } from './dslToGraph'
import type { Node, Edge } from '@xyflow/react'
import type { RulePackageDSL, RulePackageDSLV3, MTFGuardNodeData } from '../types'

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

function makeAccountRisk(id = 'ar1'): Node {
  return {
    id, type: 'accountRisk', position: { x: 200, y: 500 },
    data: { maxDailyLoss: 0.03, maxWeeklyLoss: 0.08, maxConsecutiveLosses: 4, killSwitchEnabled: true },
  }
}

function makeMTFGuard(id = 'mg1'): Node {
  const guardData: MTFGuardNodeData = {
    guardId: 'guard_1',
    name: 'OB Guard',
    fastTimeframe: '5m',
    slowTimeframe: '1h',
    sourceNode: 'entry_ob',
    targetNode: 'exec_out',
    structureType: 'order_block',
    shadowWindow: { mode: 'strict', maxFastCandles: 12, allowLowTfTouch: false, allowLowTfUpdateFilledRatio: false },
    violationPolicy: { temporaryViolation: 'hold', reclaimPending: 'reduce', confirmedReclaim: 'resume', confirmedBreak: 'exit' },
  }
  return { id, type: 'mtfGuard', position: { x: 350, y: 500 }, data: guardData }
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

function fullV3Graph() {
  const { nodes, edges } = fullGraph()
  nodes.push(makeAccountRisk())
  nodes.push(makeMTFGuard())
  edges.push(edge('ar1', 'out1', 'accountRisk', 'risk'))
  edges.push(edge('s1', 'mg1', 'signal', 'guard-in'))
  edges.push(edge('mg1', 'out1', 'guard-out', 'filters'))
  return { nodes, edges }
}

describe('graphToDsl v2.5', () => {
  it('converts a complete graph to valid DSL', () => {
    const { nodes, edges } = fullGraph()
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    expect(result.dsl).not.toBeNull()
    const dsl = result.dsl as RulePackageDSL
    expect(dsl.schema_version).toBe('2.5')
    expect(dsl.timeframe).toBe('1h')
    expect(dsl.symbols).toEqual(['BTC/USDT'])
    expect(dsl.entry.logic).toBe('AND')
    expect(dsl.entry.rules).toHaveLength(1)
    expect(dsl.exit.logic).toBe('OR')
    expect(dsl.exit.rules).toHaveLength(1)
    expect(dsl.position_sizing.position_pct).toBe(0.02)
    expect(dsl.risk.stoploss).toBe(-0.05)
    expect(dsl.risk.max_open_trades).toBe(3)
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
    const dsl = result.dsl as RulePackageDSL
    expect(dsl.entry.rules).toHaveLength(2)
  })

  it('collects filters', () => {
    const { nodes, edges } = fullGraph()
    nodes.push(makeFilter('f1'))
    edges.push(edge('s1', 'f1', 'signal', 'signal'))
    edges.push(edge('f1', 'out1', 'filtered', 'filters'))
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    const dsl = result.dsl as RulePackageDSL
    expect(dsl.filters).toHaveLength(1)
    expect(dsl.filters[0].type).toBe('volume_filter')
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
    const dsl = result.dsl as RulePackageDSL
    expect(dsl.entry.rules[0].type).toBe('indicator_cross')
    expect(dsl.entry.rules[0].cross_indicator).toBe('sma')
  })
})

describe('graphToDsl v3.0', () => {
  it('produces v3.0 DSL when mtfGuard node is present', () => {
    const { nodes, edges } = fullV3Graph()
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    expect(result.dsl).not.toBeNull()
    const dsl = result.dsl as RulePackageDSLV3
    expect(dsl.schema_version).toBe('3.0')
    expect(dsl.strategy.symbol).toBe('BTC/USDT')
    expect(dsl.strategy.timeframe).toBe('1h')
    expect(dsl.entry_logic.rules).toHaveLength(1)
    expect(dsl.exit_logic.rules).toHaveLength(1)
    expect(dsl.account_risk_policy.max_daily_loss).toBe(0.03)
    expect(dsl.account_risk_policy.kill_switch_enabled).toBe(true)
  })

  it('includes MTF guard rules in v3.0 output', () => {
    const { nodes, edges } = fullV3Graph()
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)
    const dsl = result.dsl as RulePackageDSLV3
    expect(dsl.schema_version).toBe('3.0')
    expect(dsl.mtf_guards).toBeDefined()
    expect(dsl.mtf_guards).toHaveLength(1)
    expect(dsl.mtf_guards![0].guard_id).toBe('guard_1')
    expect(dsl.mtf_guards![0].fast_timeframe).toBe('5m')
    expect(dsl.mtf_guards![0].slow_timeframe).toBe('1h')
    expect(dsl.mtf_guards![0].structure_type).toBe('order_block')
    expect(dsl.mtf_guards![0].violation_policy.confirmed_break).toBe('exit')
  })

  it('produces v2.5 DSL when only accountRisk node is present (no mtfGuard)', () => {
    const { nodes, edges } = fullGraph()
    nodes.push(makeAccountRisk())
    edges.push(edge('ar1', 'out1', 'accountRisk', 'risk'))
    const result = graphToDsl(nodes, edges)
    const dsl = result.dsl as RulePackageDSL
    expect(dsl.schema_version).toBe('2.5')
  })

  it('includes disconnect_protection in v3.0 output', () => {
    const { nodes, edges } = fullV3Graph()
    const result = graphToDsl(nodes, edges)
    const dsl = result.dsl as RulePackageDSLV3
    expect(dsl.disconnect_protection).toBeDefined()
    expect(dsl.disconnect_protection.enabled).toBe(true)
    expect(dsl.disconnect_protection.emergency_action).toBe('flatten')
  })

  it('round-trips v3.0: dslToGraph then graphToDsl preserves key fields', () => {
    const originalDsl = makeDSLV3({
      mtf_guards: [{
        guard_id: 'guard_rt',
        name: 'Round Trip Guard',
        fast_timeframe: '15m',
        slow_timeframe: '4h',
        source_node: 'entry_ob',
        target_node: 'exec_out',
        structure_type: 'fvg',
        shadow_window: { mode: 'relaxed', max_fast_candles: 8, allow_low_tf_touch: true, allow_low_tf_update_filled_ratio: false },
        violation_policy: { temporary_violation: 'reduce', reclaim_pending: 'hold', confirmed_reclaim: 'resume', confirmed_break: 'flatten' },
      }],
    })

    resetIdCounter()
    const { nodes, edges } = dslToGraph(originalDsl)
    const result = graphToDsl(nodes, edges)
    expect(result.errors).toHaveLength(0)

    const roundTripped = result.dsl as RulePackageDSLV3
    expect(roundTripped.schema_version).toBe('3.0')
    expect(roundTripped.strategy.timeframe).toBe('1h')
    expect(roundTripped.strategy.symbol).toBe('BTC/USDT')
    expect(roundTripped.entry_logic.rules).toHaveLength(1)
    expect(roundTripped.exit_logic.rules).toHaveLength(1)
    expect(roundTripped.account_risk_policy.max_daily_loss).toBe(0.03)
    expect(roundTripped.mtf_guards).toHaveLength(1)
    expect(roundTripped.mtf_guards![0].guard_id).toBe('guard_rt')
    expect(roundTripped.mtf_guards![0].fast_timeframe).toBe('15m')
    expect(roundTripped.mtf_guards![0].slow_timeframe).toBe('4h')
    expect(roundTripped.mtf_guards![0].structure_type).toBe('fvg')
    expect(roundTripped.mtf_guards![0].shadow_window.mode).toBe('relaxed')
    expect(roundTripped.mtf_guards![0].shadow_window.max_fast_candles).toBe(8)
    expect(roundTripped.mtf_guards![0].violation_policy.confirmed_break).toBe('flatten')
  })
})
