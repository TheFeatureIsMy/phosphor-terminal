export type NodeType =
  | 'signalInput'
  | 'indicatorCondition'
  | 'filter'
  | 'positionSizing'
  | 'riskPolicy'
  | 'executionOutput'
  | 'structureDefense'
  | 'accountRisk'
  | 'mtfGuard'

// --- Node data types (index signature required by React Flow v12) ---

export interface SignalInputData {
  [key: string]: unknown
  timeframe: string
  symbols: string[]
}

export interface IndicatorConditionData {
  [key: string]: unknown
  ruleType: 'indicator_threshold' | 'indicator_cross'
  indicator: string
  params: Record<string, number>
  operator: string
  value?: number
  minValue?: number
  maxValue?: number
  crossIndicator?: string
  crossParams?: Record<string, number>
  direction?: 'crosses_above' | 'crosses_below'
}

export interface FilterData {
  [key: string]: unknown
  ruleType: string
  indicator?: string
  params?: Record<string, number>
  operator?: string
  value?: number
  maxScore?: number
  candles?: number
  maxExposurePct?: number
  minConfidence?: number
  missingDataPolicy?: string
}

export interface PositionSizingData {
  [key: string]: unknown
  type: 'fixed_pct'
  positionPct: number
}

export interface RiskPolicyData {
  [key: string]: unknown
  stoploss: number
  maxOpenTrades: number
  trailingStop?: boolean
  trailingStopPositive?: number
  trailingStopPositiveOffset?: number
  cooldown?: number
}

export interface ExecutionOutputData {
  [key: string]: unknown
  entryLogic: 'AND' | 'OR'
  exitLogic: 'AND' | 'OR'
  schemaVersion: '2.5' | '3.0'
}


export interface MTFGuardNodeData {
  [key: string]: unknown
  guardId: string
  name: string
  fastTimeframe: string
  slowTimeframe: string
  sourceNode: string
  targetNode: string
  structureType: string
  shadowWindow: {
    mode: string
    maxFastCandles: number
    allowLowTfTouch: boolean
    allowLowTfUpdateFilledRatio: boolean
  }
  violationPolicy: {
    temporaryViolation: string
    reclaimPending: string
    confirmedReclaim: string
    confirmedBreak: string
  }
}

export interface MTFGuardEdgeData {
  [key: string]: unknown
  guardState: 'confirmed' | 'watching' | 'pending_htf_close' | 'temporary_violation' | 'reclaim_pending' | 'invalidated' | 'expired' | 'inactive'
  guardId: string
  fastTimeframe: string
  slowTimeframe: string
  reasonCodes: string[]
}

export type CanvasNodeData =
  | SignalInputData
  | IndicatorConditionData
  | FilterData
  | PositionSizingData
  | RiskPolicyData
  | ExecutionOutputData
  | MTFGuardNodeData

// --- DSL types ---

export interface DSLError {
  code: string
  path: string
  message: string
  severity: 'error' | 'warning'
}

export interface ValidationReport {
  valid: boolean
  errorCount: number
  warningCount: number
  safeHoldRequired: boolean
  safeHoldReasons: string[]
  errors: DSLError[]
  warnings: DSLError[]
}

export interface DSLRule {
  type: string
  indicator?: string
  params?: Record<string, number>
  operator?: string
  value?: number
  min_value?: number
  max_value?: number
  cross_indicator?: string
  cross_params?: Record<string, number>
  direction?: string
  max_score?: number
  candles?: number
  max_exposure_pct?: number
  min_confidence?: string
  missing_data_policy?: string
  required_direction?: string
}

export interface RuleGroup {
  logic: 'AND' | 'OR'
  rules: DSLRule[]
}

export interface RulePackageDSL {
  schema_version: '2.5'
  timeframe: string
  symbols: string[]
  entry: RuleGroup
  exit: RuleGroup
  filters: DSLRule[]
  position_sizing: { type: 'fixed_pct'; position_pct: number }
  risk: {
    stoploss: number
    max_open_trades: number
    trailing_stop?: boolean
    trailing_stop_positive?: number
    trailing_stop_positive_offset?: number
    cooldown?: number
  }
  metadata: Record<string, unknown>
}

// --- Bridge messages ---

export type SwiftToReactMessage =
  | { type: 'loadGraph'; payload: { nodes: unknown[]; edges: unknown[] } }
  | { type: 'loadDSL'; payload: { dsl: AnyRulePackageDSL } }
  | { type: 'validationResult'; payload: ValidationReport }
  | { type: 'mtfGuardStateUpdate'; payload: { guardId: string; state: string; action: string; reasonCodes: string[] } }

export type ReactToSwiftMessage =
  | { type: 'canvasReady' }
  | { type: 'graphChanged'; payload: { dsl: AnyRulePackageDSL | null; graphState: string } }
  | { type: 'requestValidation'; payload: { dsl: AnyRulePackageDSL } }
  | { type: 'requestSaveVersion'; payload: { dsl: AnyRulePackageDSL } }

export interface NodeValidationState {
  errors: DSLError[]
  warnings: DSLError[]
}

// ── DSL v3.0 types ──────────────────────────────────────────────────

export interface StructureDefenseData {
  [key: string]: unknown
  structures: string[]
  minStructureScore: number
}

export interface AccountRiskData {
  [key: string]: unknown
  maxDailyLoss: number
  maxWeeklyLoss: number
  maxConsecutiveLosses: number
  killSwitchEnabled: boolean
}

export interface StrategyMetaDSL {
  id: string
  name: string
  symbol: string
  timeframe: string
  mode: 'auto' | 'semi_auto' | 'manual'
}

export interface StopPolicyDSL {
  mode: string
  priority?: string[]
  atr_buffer_coef?: number
  fallback_stop_pct: number
  max_stop_distance_pct?: number
  min_reward_risk?: number
}

export interface AccountRiskPolicyDSL {
  max_daily_loss: number
  max_weekly_loss: number
  max_consecutive_losses: number
  kill_switch_enabled: boolean
}

export interface DisconnectProtectionDSL {
  enabled: boolean
  max_snapshot_miss_ticks: number
  hard_disconnect_timeout_ms: number
  fallback_stop_pct: number
  emergency_action: string
}


export interface MTFGuardRuleDSL {
  guard_id: string
  name: string
  fast_timeframe: string
  slow_timeframe: string
  source_node: string
  target_node: string
  structure_type: string
  shadow_window: {
    mode: string
    max_fast_candles: number
    allow_low_tf_touch: boolean
    allow_low_tf_update_filled_ratio: boolean
  }
  violation_policy: {
    temporary_violation: string
    reclaim_pending: string
    confirmed_reclaim: string
    confirmed_break: string
  }
}

export interface RulePackageDSLV3 {
  schema_version: '3.0'
  strategy: StrategyMetaDSL
  entry_logic: RuleGroup
  exit_logic: RuleGroup
  filters: DSLRule[]
  stop_policy: StopPolicyDSL
  position_policy: { risk_per_trade: number; max_position_pct: number }
  account_risk_policy: AccountRiskPolicyDSL
  disconnect_protection: DisconnectProtectionDSL
  mtf_guards?: MTFGuardRuleDSL[]
  metadata: Record<string, unknown>
}

export type AnyRulePackageDSL = RulePackageDSL | RulePackageDSLV3
