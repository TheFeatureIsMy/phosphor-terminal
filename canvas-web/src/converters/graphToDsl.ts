import type { Node, Edge } from '@xyflow/react'
import type {
  RulePackageDSL, RulePackageDSLV3, AnyRulePackageDSL, DSLRule,
  SignalInputData, IndicatorConditionData, FilterData,
  PositionSizingData, RiskPolicyData, ExecutionOutputData,
  StructureDefenseData, AccountRiskData, MTFGuardNodeData, MTFGuardRuleDSL,
} from '../types'

export interface ConvertError {
  message: string
  nodeId?: string
}

export interface ConvertResult {
  dsl: AnyRulePackageDSL | null
  errors: ConvertError[]
  warnings: ConvertError[]
}

function asData<T>(node: Node): T {
  return node.data as unknown as T
}

/**
 * Detect whether the graph contains any v3.0-only node types.
 */
function hasV3Nodes(nodes: Node[]): boolean {
  return nodes.some(n => n.type === 'mtfGuard')
}

export function graphToDsl(nodes: Node[], edges: Edge[]): ConvertResult {
  if (hasV3Nodes(nodes)) {
    return graphToDslV3(nodes, edges)
  }
  return graphToDslV25(nodes, edges)
}

// ─── v2.5 converter (original logic, unchanged) ─────────────────────

function graphToDslV25(nodes: Node[], edges: Edge[]): ConvertResult {
  const errors: ConvertError[] = []
  const warnings: ConvertError[] = []

  const signalNodes = nodes.filter(n => n.type === 'signalInput')
  const outputNodes = nodes.filter(n => n.type === 'executionOutput')
  const conditionNodes = nodes.filter(n => n.type === 'indicatorCondition')
  const filterNodes = nodes.filter(n => n.type === 'filter')
  const sizingNodes = nodes.filter(n => n.type === 'positionSizing')
  const riskNodes = nodes.filter(n => n.type === 'riskPolicy')

  if (signalNodes.length === 0) errors.push({ message: '需要信号输入节点' })
  if (signalNodes.length > 1) errors.push({ message: '只允许一个信号输入节点', nodeId: signalNodes[1].id })
  if (outputNodes.length === 0) errors.push({ message: '需要执行输出节点' })
  if (outputNodes.length > 1) errors.push({ message: '只允许一个执行输出节点', nodeId: outputNodes[1].id })

  if (errors.length > 0) return { dsl: null, errors, warnings }

  const signalData = asData<SignalInputData>(signalNodes[0])
  const outputData = asData<ExecutionOutputData>(outputNodes[0])
  const outputId = outputNodes[0].id

  const entryEdges = edges.filter(e => e.target === outputId && e.targetHandle === 'entryConditions')
  const exitEdges = edges.filter(e => e.target === outputId && e.targetHandle === 'exitConditions')
  const filterEdges = edges.filter(e => e.target === outputId && e.targetHandle === 'filters')
  const sizingEdge = edges.find(e => e.target === outputId && e.targetHandle === 'sizing')
  const riskEdge = edges.find(e => e.target === outputId && e.targetHandle === 'risk')

  const entryRules: DSLRule[] = []
  for (const edge of entryEdges) {
    const node = conditionNodes.find(n => n.id === edge.source)
    if (node) entryRules.push(conditionToRule(asData<IndicatorConditionData>(node)))
  }
  const exitRules: DSLRule[] = []
  for (const edge of exitEdges) {
    const node = conditionNodes.find(n => n.id === edge.source)
    if (node) exitRules.push(conditionToRule(asData<IndicatorConditionData>(node)))
  }

  if (entryRules.length === 0) errors.push({ message: '至少需要一条入场条件' })
  if (exitRules.length === 0) errors.push({ message: '至少需要一条出场条件' })

  const filters: DSLRule[] = []
  for (const edge of filterEdges) {
    const node = filterNodes.find(n => n.id === edge.source)
    if (node) filters.push(filterToRule(asData<FilterData>(node)))
  }

  let positionSizing = { type: 'fixed_pct' as const, position_pct: 0.02 }
  if (sizingEdge) {
    const node = sizingNodes.find(n => n.id === sizingEdge.source)
    if (node) {
      const d = asData<PositionSizingData>(node)
      positionSizing = { type: 'fixed_pct', position_pct: d.positionPct }
    }
  } else if (sizingNodes.length > 0) {
    warnings.push({ message: '仓位管理节点未连接到执行输出', nodeId: sizingNodes[0].id })
  }

  let risk: RulePackageDSL['risk'] = { stoploss: -0.05, max_open_trades: 3 }
  if (riskEdge) {
    const node = riskNodes.find(n => n.id === riskEdge.source)
    if (node) {
      const d = asData<RiskPolicyData>(node)
      const r: RulePackageDSL['risk'] = { stoploss: d.stoploss, max_open_trades: d.maxOpenTrades }
      if (d.trailingStop != null) r.trailing_stop = d.trailingStop
      if (d.trailingStopPositive != null) r.trailing_stop_positive = d.trailingStopPositive
      if (d.trailingStopPositiveOffset != null) r.trailing_stop_positive_offset = d.trailingStopPositiveOffset
      if (d.cooldown != null) r.cooldown = d.cooldown
      risk = r
    }
  } else if (riskNodes.length > 0) {
    warnings.push({ message: '风控策略节点未连接到执行输出', nodeId: riskNodes[0].id })
  }

  // Warn about disconnected nodes
  const connectedIds = new Set<string>()
  connectedIds.add(signalNodes[0].id)
  connectedIds.add(outputId)
  for (const e of edges) { connectedIds.add(e.source); connectedIds.add(e.target) }
  for (const n of nodes) {
    if (!connectedIds.has(n.id)) warnings.push({ message: '节点未连接', nodeId: n.id })
  }

  if (errors.length > 0) return { dsl: null, errors, warnings }

  const dsl: RulePackageDSL = {
    schema_version: '2.5',
    timeframe: signalData.timeframe,
    symbols: signalData.symbols,
    entry: { logic: outputData.entryLogic, rules: entryRules },
    exit: { logic: outputData.exitLogic, rules: exitRules },
    filters,
    position_sizing: positionSizing,
    risk,
    metadata: {},
  }

  return { dsl, errors: [], warnings }
}

// ─── v3.0 converter ──────────────────────────────────────────────────

function graphToDslV3(nodes: Node[], edges: Edge[]): ConvertResult {
  const errors: ConvertError[] = []
  const warnings: ConvertError[] = []

  const signalNodes = nodes.filter(n => n.type === 'signalInput')
  const outputNodes = nodes.filter(n => n.type === 'executionOutput')
  const conditionNodes = nodes.filter(n => n.type === 'indicatorCondition')
  const filterNodes = nodes.filter(n => n.type === 'filter')
  const sizingNodes = nodes.filter(n => n.type === 'positionSizing')
  const riskNodes = nodes.filter(n => n.type === 'riskPolicy')
  const accountRiskNodes = nodes.filter(n => n.type === 'accountRisk')
  const structureDefenseNodes = nodes.filter(n => n.type === 'structureDefense')
  const mtfGuardNodes = nodes.filter(n => n.type === 'mtfGuard')

  if (signalNodes.length === 0) errors.push({ message: '需要信号输入节点' })
  if (signalNodes.length > 1) errors.push({ message: '只允许一个信号输入节点', nodeId: signalNodes[1].id })
  if (outputNodes.length === 0) errors.push({ message: '需要执行输出节点' })
  if (outputNodes.length > 1) errors.push({ message: '只允许一个执行输出节点', nodeId: outputNodes[1].id })

  if (errors.length > 0) return { dsl: null, errors, warnings }

  const signalData = asData<SignalInputData>(signalNodes[0])
  const outputData = asData<ExecutionOutputData>(outputNodes[0])
  const outputId = outputNodes[0].id

  // Entry/exit conditions
  const entryEdges = edges.filter(e => e.target === outputId && e.targetHandle === 'entryConditions')
  const exitEdges = edges.filter(e => e.target === outputId && e.targetHandle === 'exitConditions')
  const filterEdges = edges.filter(e => e.target === outputId && e.targetHandle === 'filters')
  const sizingEdge = edges.find(e => e.target === outputId && e.targetHandle === 'sizing')
  const riskEdge = edges.find(e => e.target === outputId && e.targetHandle === 'risk')

  const entryRules: DSLRule[] = []
  for (const edge of entryEdges) {
    const node = conditionNodes.find(n => n.id === edge.source)
    if (node) entryRules.push(conditionToRule(asData<IndicatorConditionData>(node)))
  }
  const exitRules: DSLRule[] = []
  for (const edge of exitEdges) {
    const node = conditionNodes.find(n => n.id === edge.source)
    if (node) exitRules.push(conditionToRule(asData<IndicatorConditionData>(node)))
  }

  if (entryRules.length === 0) errors.push({ message: '至少需要一条入场条件' })
  if (exitRules.length === 0) errors.push({ message: '至少需要一条出场条件' })

  const filters: DSLRule[] = []
  for (const edge of filterEdges) {
    const node = filterNodes.find(n => n.id === edge.source)
    if (node) filters.push(filterToRule(asData<FilterData>(node)))
  }

  // Position policy
  let riskPerTrade = 0.02
  let maxPositionPct = 0.1
  if (sizingEdge) {
    const node = sizingNodes.find(n => n.id === sizingEdge.source)
    if (node) {
      const d = asData<PositionSizingData>(node)
      riskPerTrade = d.positionPct
      maxPositionPct = Math.min(d.positionPct * 5, 1)
    }
  } else if (sizingNodes.length > 0) {
    warnings.push({ message: '仓位管理节点未连接到执行输出', nodeId: sizingNodes[0].id })
  }

  // Stop policy from risk node
  let fallbackStopPct = 0.05
  if (riskEdge) {
    const node = riskNodes.find(n => n.id === riskEdge.source)
    if (node) {
      const d = asData<RiskPolicyData>(node)
      fallbackStopPct = Math.abs(d.stoploss)
    }
  } else if (riskNodes.length > 0) {
    warnings.push({ message: '风控策略节点未连接到执行输出', nodeId: riskNodes[0].id })
  }

  // Account risk policy
  let accountRiskPolicy = {
    max_daily_loss: 0.03,
    max_weekly_loss: 0.08,
    max_consecutive_losses: 4,
    kill_switch_enabled: true,
  }
  if (accountRiskNodes.length > 0) {
    const d = asData<AccountRiskData>(accountRiskNodes[0])
    accountRiskPolicy = {
      max_daily_loss: d.maxDailyLoss,
      max_weekly_loss: d.maxWeeklyLoss,
      max_consecutive_losses: d.maxConsecutiveLosses,
      kill_switch_enabled: d.killSwitchEnabled,
    }
  }

  // MTF Guards
  const mtfGuards: MTFGuardRuleDSL[] = []
  for (const guardNode of mtfGuardNodes) {
    const d = asData<MTFGuardNodeData>(guardNode)
    mtfGuards.push({
      guard_id: d.guardId,
      name: d.name,
      fast_timeframe: d.fastTimeframe,
      slow_timeframe: d.slowTimeframe,
      source_node: d.sourceNode,
      target_node: d.targetNode,
      structure_type: d.structureType,
      shadow_window: {
        mode: d.shadowWindow.mode,
        max_fast_candles: d.shadowWindow.maxFastCandles,
        allow_low_tf_touch: d.shadowWindow.allowLowTfTouch,
        allow_low_tf_update_filled_ratio: d.shadowWindow.allowLowTfUpdateFilledRatio,
      },
      violation_policy: {
        temporary_violation: d.violationPolicy.temporaryViolation,
        reclaim_pending: d.violationPolicy.reclaimPending,
        confirmed_reclaim: d.violationPolicy.confirmedReclaim,
        confirmed_break: d.violationPolicy.confirmedBreak,
      },
    })
  }

  // Warn about disconnected nodes
  const connectedIds = new Set<string>()
  connectedIds.add(signalNodes[0].id)
  connectedIds.add(outputId)
  for (const e of edges) { connectedIds.add(e.source); connectedIds.add(e.target) }
  for (const n of nodes) {
    if (!connectedIds.has(n.id)) warnings.push({ message: '节点未连接', nodeId: n.id })
  }

  if (errors.length > 0) return { dsl: null, errors, warnings }

  const dsl: RulePackageDSLV3 = {
    schema_version: '3.0',
    strategy: {
      id: '',
      name: '',
      symbol: signalData.symbols[0] ?? 'BTC/USDT',
      timeframe: signalData.timeframe,
      mode: 'auto',
    },
    entry_logic: { logic: outputData.entryLogic, rules: entryRules },
    exit_logic: { logic: outputData.exitLogic, rules: exitRules },
    filters,
    stop_policy: structureDefenseNodes.length > 0
      ? {
          mode: 'structure_invalidated',
          priority: asData<StructureDefenseData>(structureDefenseNodes[0]).structures,
          fallback_stop_pct: fallbackStopPct,
        }
      : {
          mode: 'fixed',
          fallback_stop_pct: fallbackStopPct,
        },
    position_policy: {
      risk_per_trade: riskPerTrade,
      max_position_pct: maxPositionPct,
    },
    account_risk_policy: accountRiskPolicy,
    disconnect_protection: {
      enabled: true,
      max_snapshot_miss_ticks: 3,
      hard_disconnect_timeout_ms: 30000,
      fallback_stop_pct: fallbackStopPct,
      emergency_action: 'flatten',
    },
    mtf_guards: mtfGuards.length > 0 ? mtfGuards : undefined,
    metadata: {},
  }

  return { dsl, errors: [], warnings }
}

// ─── Shared helpers ──────────────────────────────────────────────────

function conditionToRule(data: IndicatorConditionData): DSLRule {
  if (data.ruleType === 'indicator_cross') {
    return {
      type: 'indicator_cross',
      indicator: data.indicator,
      params: data.params ?? {},
      cross_indicator: data.crossIndicator,
      cross_params: data.crossParams ?? {},
      direction: data.direction ?? 'crosses_above',
    }
  }
  const rule: DSLRule = {
    type: 'indicator_threshold',
    indicator: data.indicator,
    params: data.params ?? {},
    operator: data.operator,
  }
  if (['between', 'not_between'].includes(data.operator)) {
    rule.min_value = data.minValue
    rule.max_value = data.maxValue
  } else {
    rule.value = data.value
  }
  return rule
}

function filterToRule(data: FilterData): DSLRule {
  const rule: DSLRule = { type: data.ruleType }
  if (data.indicator) rule.indicator = data.indicator
  if (data.params) rule.params = data.params
  if (data.operator) rule.operator = data.operator
  if (data.value != null) rule.value = data.value
  if (data.maxScore != null) rule.max_score = data.maxScore
  if (data.candles != null) rule.candles = data.candles
  if (data.maxExposurePct != null) rule.max_exposure_pct = data.maxExposurePct
  if (data.minConfidence != null) rule.min_confidence = String(data.minConfidence)
  if (data.missingDataPolicy) rule.missing_data_policy = data.missingDataPolicy
  return rule
}
