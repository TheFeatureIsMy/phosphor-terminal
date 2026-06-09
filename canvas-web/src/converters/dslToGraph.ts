import type { Node, Edge } from '@xyflow/react'
import type {
  RulePackageDSL, RulePackageDSLV3, AnyRulePackageDSL, DSLRule,
  SignalInputData, IndicatorConditionData, FilterData,
  PositionSizingData, RiskPolicyData, ExecutionOutputData,
  StructureDefenseData, AccountRiskData, MTFGuardNodeData, MTFGuardEdgeData,
  MTFGuardRuleDSL,
} from '../types'

let idCounter = 0
function nextId(): string {
  return `node_${++idCounter}`
}

export function resetIdCounter() {
  idCounter = 0
}

/**
 * Convert any DSL version to React Flow graph.
 * Accepts both v2.5 RulePackageDSL and v3.0 RulePackageDSLV3.
 */
export function dslToGraph(dsl: AnyRulePackageDSL): { nodes: Node[]; edges: Edge[] } {
  if (dsl.schema_version === '3.0') {
    return dslV3ToGraph(dsl as RulePackageDSLV3)
  }
  return dslV25ToGraph(dsl as RulePackageDSL)
}

// ─── v2.5 converter (unchanged logic) ────────────────────────────────

function dslV25ToGraph(dsl: RulePackageDSL): { nodes: Node[]; edges: Edge[] } {
  resetIdCounter()
  const nodes: Node[] = []
  const edges: Edge[] = []

  const signalId = nextId()
  nodes.push({
    id: signalId,
    type: 'signalInput',
    position: { x: 0, y: 250 },
    data: { timeframe: dsl.timeframe, symbols: [...dsl.symbols] } satisfies SignalInputData,
  })

  const outputId = nextId()
  nodes.push({
    id: outputId,
    type: 'executionOutput',
    position: { x: 800, y: 200 },
    data: {
      entryLogic: dsl.entry.logic,
      exitLogic: dsl.exit.logic,
      schemaVersion: '2.5',
    } satisfies ExecutionOutputData,
  })

  let yEntry = 50
  for (const rule of dsl.entry.rules) {
    const nodeId = nextId()
    nodes.push({
      id: nodeId,
      type: 'indicatorCondition',
      position: { x: 300, y: yEntry },
      data: ruleToConditionData(rule),
    })
    edges.push(
      { id: `e_${signalId}_${nodeId}`, source: signalId, target: nodeId, sourceHandle: 'signal', targetHandle: 'signal' },
      { id: `e_${nodeId}_${outputId}_entry`, source: nodeId, target: outputId, sourceHandle: 'condition', targetHandle: 'entryConditions' },
    )
    yEntry += 140
  }

  let yExit = yEntry + 40
  for (const rule of dsl.exit.rules) {
    const nodeId = nextId()
    nodes.push({
      id: nodeId,
      type: 'indicatorCondition',
      position: { x: 300, y: yExit },
      data: ruleToConditionData(rule),
    })
    edges.push(
      { id: `e_${signalId}_${nodeId}`, source: signalId, target: nodeId, sourceHandle: 'signal', targetHandle: 'signal' },
      { id: `e_${nodeId}_${outputId}_exit`, source: nodeId, target: outputId, sourceHandle: 'condition', targetHandle: 'exitConditions' },
    )
    yExit += 140
  }

  let yFilter = 50
  for (const rule of dsl.filters ?? []) {
    const nodeId = nextId()
    nodes.push({
      id: nodeId,
      type: 'filter',
      position: { x: 550, y: yFilter },
      data: ruleToFilterData(rule),
    })
    edges.push(
      { id: `e_${signalId}_${nodeId}`, source: signalId, target: nodeId, sourceHandle: 'signal', targetHandle: 'signal' },
      { id: `e_${nodeId}_${outputId}_filter`, source: nodeId, target: outputId, sourceHandle: 'filtered', targetHandle: 'filters' },
    )
    yFilter += 140
  }

  const sizingId = nextId()
  nodes.push({
    id: sizingId,
    type: 'positionSizing',
    position: { x: 550, y: Math.max(yFilter, yExit) + 30 },
    data: {
      type: 'fixed_pct',
      positionPct: dsl.position_sizing.position_pct,
    } satisfies PositionSizingData,
  })
  edges.push({
    id: `e_${sizingId}_${outputId}`,
    source: sizingId, target: outputId,
    sourceHandle: 'sizing', targetHandle: 'sizing',
  })

  const riskId = nextId()
  const riskData: RiskPolicyData = {
    stoploss: dsl.risk.stoploss,
    maxOpenTrades: dsl.risk.max_open_trades,
  }
  if (dsl.risk.trailing_stop != null) riskData.trailingStop = dsl.risk.trailing_stop
  if (dsl.risk.trailing_stop_positive != null) riskData.trailingStopPositive = dsl.risk.trailing_stop_positive
  if (dsl.risk.trailing_stop_positive_offset != null) riskData.trailingStopPositiveOffset = dsl.risk.trailing_stop_positive_offset
  if (dsl.risk.cooldown != null) riskData.cooldown = dsl.risk.cooldown

  nodes.push({
    id: riskId,
    type: 'riskPolicy',
    position: { x: 550, y: Math.max(yFilter, yExit) + 180 },
    data: riskData,
  })
  edges.push({
    id: `e_${riskId}_${outputId}`,
    source: riskId, target: outputId,
    sourceHandle: 'risk', targetHandle: 'risk',
  })

  return { nodes, edges }
}

// ─── v3.0 converter ──────────────────────────────────────────────────

function dslV3ToGraph(dsl: RulePackageDSLV3): { nodes: Node[]; edges: Edge[] } {
  resetIdCounter()
  const nodes: Node[] = []
  const edges: Edge[] = []

  // Signal input from strategy meta
  const signalId = nextId()
  nodes.push({
    id: signalId,
    type: 'signalInput',
    position: { x: 0, y: 250 },
    data: {
      timeframe: dsl.strategy.timeframe,
      symbols: [dsl.strategy.symbol],
    } satisfies SignalInputData,
  })

  // Execution output
  const outputId = nextId()
  nodes.push({
    id: outputId,
    type: 'executionOutput',
    position: { x: 800, y: 200 },
    data: {
      entryLogic: dsl.entry_logic.logic,
      exitLogic: dsl.exit_logic.logic,
      schemaVersion: '3.0',
    } satisfies ExecutionOutputData,
  })

  // Entry conditions
  let yEntry = 50
  for (const rule of dsl.entry_logic.rules) {
    const nodeId = nextId()
    nodes.push({
      id: nodeId,
      type: 'indicatorCondition',
      position: { x: 300, y: yEntry },
      data: ruleToConditionData(rule),
    })
    edges.push(
      { id: `e_${signalId}_${nodeId}`, source: signalId, target: nodeId, sourceHandle: 'signal', targetHandle: 'signal' },
      { id: `e_${nodeId}_${outputId}_entry`, source: nodeId, target: outputId, sourceHandle: 'condition', targetHandle: 'entryConditions' },
    )
    yEntry += 140
  }

  // Exit conditions
  let yExit = yEntry + 40
  for (const rule of dsl.exit_logic.rules) {
    const nodeId = nextId()
    nodes.push({
      id: nodeId,
      type: 'indicatorCondition',
      position: { x: 300, y: yExit },
      data: ruleToConditionData(rule),
    })
    edges.push(
      { id: `e_${signalId}_${nodeId}`, source: signalId, target: nodeId, sourceHandle: 'signal', targetHandle: 'signal' },
      { id: `e_${nodeId}_${outputId}_exit`, source: nodeId, target: outputId, sourceHandle: 'condition', targetHandle: 'exitConditions' },
    )
    yExit += 140
  }

  // Filters
  let yFilter = 50
  for (const rule of dsl.filters ?? []) {
    const nodeId = nextId()
    nodes.push({
      id: nodeId,
      type: 'filter',
      position: { x: 550, y: yFilter },
      data: ruleToFilterData(rule),
    })
    edges.push(
      { id: `e_${signalId}_${nodeId}`, source: signalId, target: nodeId, sourceHandle: 'signal', targetHandle: 'signal' },
      { id: `e_${nodeId}_${outputId}_filter`, source: nodeId, target: outputId, sourceHandle: 'filtered', targetHandle: 'filters' },
    )
    yFilter += 140
  }

  // Position sizing
  const sizingId = nextId()
  nodes.push({
    id: sizingId,
    type: 'positionSizing',
    position: { x: 550, y: Math.max(yFilter, yExit) + 30 },
    data: {
      type: 'fixed_pct',
      positionPct: dsl.position_policy.risk_per_trade,
    } satisfies PositionSizingData,
  })
  edges.push({
    id: `e_${sizingId}_${outputId}`,
    source: sizingId, target: outputId,
    sourceHandle: 'sizing', targetHandle: 'sizing',
  })

  // Risk policy (from stop_policy)
  const riskId = nextId()
  nodes.push({
    id: riskId,
    type: 'riskPolicy',
    position: { x: 550, y: Math.max(yFilter, yExit) + 180 },
    data: {
      stoploss: -dsl.stop_policy.fallback_stop_pct,
      maxOpenTrades: 1,
    } satisfies RiskPolicyData,
  })
  edges.push({
    id: `e_${riskId}_${outputId}`,
    source: riskId, target: outputId,
    sourceHandle: 'risk', targetHandle: 'risk',
  })

  // Structure defense placeholder (from stop_policy.mode if structural)
  let yExtra = Math.max(yFilter, yExit) + 340
  if (dsl.stop_policy.mode === 'structure_based' || dsl.stop_policy.priority?.includes('structure')) {
    const sdId = nextId()
    nodes.push({
      id: sdId,
      type: 'structureDefense',
      position: { x: 150, y: yExtra },
      data: {
        structures: dsl.stop_policy.priority ?? ['order_block'],
        minStructureScore: 70,
      } satisfies StructureDefenseData,
    })
    edges.push({
      id: `e_${sdId}_${outputId}`,
      source: sdId, target: outputId,
      sourceHandle: 'defense', targetHandle: 'filters',
    })
    yExtra += 160
  }

  // Account risk firewall
  const arId = nextId()
  nodes.push({
    id: arId,
    type: 'accountRisk',
    position: { x: 150, y: yExtra },
    data: {
      maxDailyLoss: dsl.account_risk_policy.max_daily_loss,
      maxWeeklyLoss: dsl.account_risk_policy.max_weekly_loss,
      maxConsecutiveLosses: dsl.account_risk_policy.max_consecutive_losses,
      killSwitchEnabled: dsl.account_risk_policy.kill_switch_enabled,
    } satisfies AccountRiskData,
  })
  edges.push({
    id: `e_${arId}_${outputId}`,
    source: arId, target: outputId,
    sourceHandle: 'accountRisk', targetHandle: 'risk',
  })
  yExtra += 160

  // MTF Guards
  const mtfGuards = dsl.mtf_guards ?? []
  for (const guard of mtfGuards) {
    const guardNodeId = nextId()
    const guardData: MTFGuardNodeData = {
      guardId: guard.guard_id,
      name: guard.name,
      fastTimeframe: guard.fast_timeframe,
      slowTimeframe: guard.slow_timeframe,
      sourceNode: guard.source_node,
      targetNode: guard.target_node,
      structureType: guard.structure_type,
      shadowWindow: {
        mode: guard.shadow_window.mode,
        maxFastCandles: guard.shadow_window.max_fast_candles,
        allowLowTfTouch: guard.shadow_window.allow_low_tf_touch,
        allowLowTfUpdateFilledRatio: guard.shadow_window.allow_low_tf_update_filled_ratio,
      },
      violationPolicy: {
        temporaryViolation: guard.violation_policy.temporary_violation,
        reclaimPending: guard.violation_policy.reclaim_pending,
        confirmedReclaim: guard.violation_policy.confirmed_reclaim,
        confirmedBreak: guard.violation_policy.confirmed_break,
      },
    }

    nodes.push({
      id: guardNodeId,
      type: 'mtfGuard',
      position: { x: 350, y: yExtra },
      data: guardData,
    })

    // Create an MTF Guard edge from signalInput to the guard node
    const guardEdgeData: MTFGuardEdgeData = {
      guardState: 'watching',
      guardId: guard.guard_id,
      fastTimeframe: guard.fast_timeframe,
      slowTimeframe: guard.slow_timeframe,
      reasonCodes: [],
    }

    edges.push({
      id: `e_${signalId}_${guardNodeId}_guard`,
      source: signalId,
      target: guardNodeId,
      sourceHandle: 'signal',
      targetHandle: 'guard-in',
      type: 'mtfGuard',
      data: guardEdgeData,
    })

    // Connect guard node to execution output
    edges.push({
      id: `e_${guardNodeId}_${outputId}_guard`,
      source: guardNodeId,
      target: outputId,
      sourceHandle: 'guard-out',
      targetHandle: 'filters',
    })

    yExtra += 180
  }

  return { nodes, edges }
}

// ─── Shared helpers ──────────────────────────────────────────────────

function ruleToConditionData(rule: DSLRule): IndicatorConditionData {
  if (rule.type === 'indicator_cross') {
    return {
      ruleType: 'indicator_cross',
      indicator: rule.indicator ?? 'ema',
      params: (rule.params ?? {}) as Record<string, number>,
      operator: 'crosses_above',
      crossIndicator: rule.cross_indicator,
      crossParams: (rule.cross_params ?? {}) as Record<string, number>,
      direction: (rule.direction as 'crosses_above' | 'crosses_below') ?? 'crosses_above',
    }
  }
  const data: IndicatorConditionData = {
    ruleType: 'indicator_threshold',
    indicator: rule.indicator ?? 'rsi',
    params: (rule.params ?? {}) as Record<string, number>,
    operator: rule.operator ?? '>',
  }
  if (['between', 'not_between'].includes(rule.operator ?? '')) {
    data.minValue = rule.min_value
    data.maxValue = rule.max_value
  } else {
    data.value = rule.value
  }
  return data
}

function ruleToFilterData(rule: DSLRule): FilterData {
  const data: FilterData = { ruleType: rule.type }
  if (rule.indicator) data.indicator = rule.indicator
  if (rule.params) data.params = rule.params as Record<string, number>
  if (rule.operator) data.operator = rule.operator
  if (rule.value != null) data.value = rule.value
  if (rule.max_score != null) data.maxScore = rule.max_score
  if (rule.candles != null) data.candles = rule.candles
  if (rule.max_exposure_pct != null) data.maxExposurePct = rule.max_exposure_pct
  if (rule.min_confidence != null) data.minConfidence = Number(rule.min_confidence)
  if (rule.missing_data_policy) data.missingDataPolicy = rule.missing_data_policy
  return data
}
