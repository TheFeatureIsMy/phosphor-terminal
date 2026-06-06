import type { Node, Edge } from '@xyflow/react'
import type {
  RulePackageDSL, DSLRule,
  SignalInputData, IndicatorConditionData, FilterData,
  PositionSizingData, RiskPolicyData, ExecutionOutputData,
} from '../types'

let idCounter = 0
function nextId(): string {
  return `node_${++idCounter}`
}

export function resetIdCounter() {
  idCounter = 0
}

export function dslToGraph(dsl: RulePackageDSL): { nodes: Node[]; edges: Edge[] } {
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
