import type { Node, Edge } from '@xyflow/react'
import type {
  RulePackageDSL, DSLRule,
  SignalInputData, IndicatorConditionData, FilterData,
  PositionSizingData, RiskPolicyData, ExecutionOutputData,
} from '../types'

export interface ConvertError {
  message: string
  nodeId?: string
}

export interface ConvertResult {
  dsl: RulePackageDSL | null
  errors: ConvertError[]
  warnings: ConvertError[]
}

function asData<T>(node: Node): T {
  return node.data as unknown as T
}

export function graphToDsl(nodes: Node[], edges: Edge[]): ConvertResult {
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
