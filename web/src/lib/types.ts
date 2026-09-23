// AlphaLoop BFF API 类型(对照 backend/app/schemas 手写,pilot 范围)

// ---------- 通用 ----------
export interface AvailableAction {
  type: string;
  label: string;
  enabled: boolean;
  reason?: string;
}

// ---------- /api/overview ----------
export interface AccountOverview {
  equity: number;
  currency: string;
  today_pnl_pct: number;
  week_pnl_pct: number;
  max_drawdown_pct: number;
  sharpe_ratio: number;
}

export interface RuntimeOverview {
  running_strategies: number;
  open_positions: number;
  pending_orders: number;
  reconciling_count: number;
}

export interface RiskOverview {
  global_state: string;
  daily_loss_remaining_pct: number;
  weekly_loss_remaining_pct: number;
  emergency_locked: boolean;
  reason_codes: string[];
}

export interface SystemOverview {
  live_readiness_state: string;
  fast_track_latency_ms: number;
  redis_rtt_ms: number;
  freqtrade_state: string;
  exchange_state: string;
}

export interface RecentDecision {
  time: string;
  symbol: string;
  decision: string;
  reason_codes: string[];
}

export interface AlertItem {
  level: string;
  title: string;
  symbol: string;
  time: string;
}

export interface DashboardResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  account: AccountOverview;
  runtime: RuntimeOverview;
  risk: RiskOverview;
  system: SystemOverview;
  recent_decisions: RecentDecision[];
  alerts: AlertItem[];
}

export interface ReadinessCheck {
  key: string;
  label: string;
  status: string; // healthy / warning / failed / unknown
  value: string;
  threshold: string;
  detail: string;
  group: string; // mode | strategy | capital | risk | system | execution
}

export interface LiveReadinessResponse {
  state: string;
  grand_status: string;
  score: number;
  reason_codes: string[];
  available_actions: AvailableAction[];
  can_start_paper: boolean;
  can_start_live_small: boolean;
  can_start_full_live: boolean;
  blocking_reasons: Record<string, unknown>[];
  warnings: Record<string, unknown>[];
  checks: ReadinessCheck[];
  selected_mode: string;
  selected_strategy_id: string;
  selected_capital_pool_id: string;
  selected_exchange: string;
  available_strategies: Record<string, unknown>[];
  available_capital_pools: Record<string, unknown>[];
  available_exchanges: Record<string, unknown>[];
}

export interface GlobalStatusResponse {
  system_state: string;
  risk_state: string;
  fast_track_latency_ms: number;
  freqtrade_state: string;
  redis_rtt_ms: number;
  exchange_state: string;
  open_positions: number;
  emergency_locked: boolean;
  reason_codes: string[];
}

// ---------- /api/dashboard ----------
export interface DashboardKPIs {
  total_pnl: number;
  pnl_change_pct: number;
  sharpe_ratio: number;
  max_drawdown: number;
  win_rate: number;
  active_strategies: number;
  todays_trades: number;
  open_positions: number;
  data_source?: { source: string; simulated: boolean; available: boolean; detail?: string | null };
}

export interface EquityPoint {
  date: string;
  value: number;
  drawdown: number;
}

// ---------- /api/v2/signals ----------
export interface SignalSummary {
  id: string;
  source_type: string;
  symbol: string;
  direction: string; // long | short | hold
  confidence: number;
  score: number | null;
  risk_level: string; // low | medium | high | extreme
  status: string;
  expires_at: string;
  created_at: string;
}

export interface SignalConflictCheckResponse {
  has_conflict: boolean;
  conflicting_signals: SignalSummary[];
}

// ---------- /api/execution ----------
export interface ExecutionSession {
  run_id: string;
  strategy_name: string;
  mode: string;
  status: string;
  symbol: string;
  open_positions: number;
  pending_orders: number;
  started_at: string | null;
  last_heartbeat: string | null;
  reason_codes: string[];
}

export interface ExecutionCenterResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  sessions: ExecutionSession[];
  total_running: number;
  total_open_positions: number;
  total_pending_orders: number;
  freqtrade_heartbeat: string;
  execution_latency_ms: number;
}

export interface OrderResponse {
  id: string;
  symbol: string;
  side: string;
  type: string;
  quantity: number;
  price: number | null;
  status: string;
  exchange_order_id: string | null;
  freqtrade_trade_id: string | null;
  created_at: string | null;
  reason_codes: string[];
}

export interface PositionResponse {
  id: string;
  symbol: string;
  side: string;
  avg_entry_price: number;
  current_price: number;
  quantity: number;
  unrealized_pnl: number;
  unrealized_pnl_pct: number;
  stop_loss: number | null;
  take_profit: number | null;
  state_difference: string | null;
  reason_codes: string[];
}

export interface OrdersPositionsResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  orders: OrderResponse[];
  positions: PositionResponse[];
}

export interface CommandBusEvent {
  id: string;
  command_type: string;
  status: string;
  created_at: string | null;
  completed_at: string | null;
}

export interface ReconciliationRun {
  id: string;
  status: string;
  started_at: string | null;
  completed_at: string | null;
  discrepancies: number;
  reason_codes: string[];
}

export interface ReconciliationBusResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  recent_commands: CommandBusEvent[];
  reconciliation_runs: ReconciliationRun[];
  active_leases: Record<string, unknown>[];
}

// ---------- /api/risk ----------
export interface RiskGuard {
  key: string;
  label: string;
  current_value: number;
  limit_value: number;
  remaining_pct: number;
  status: string;
  reason_codes: string[];
}

export interface RiskOverviewResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  account_state: string;
  emergency_locked: boolean;
  guards: RiskGuard[];
  active_locks: Record<string, unknown>[];
}

export interface StopLevel {
  raw_structure_stop: number | null;
  last_known_good_stop: number | null;
  secure_runtime_stop: number | null;
  exchange_protective_stop: number | null;
  volatility_locked: boolean;
}

export interface PositionStop {
  position_id: string;
  symbol: string;
  side: string;
  entry_price: number;
  current_price: number;
  stops: StopLevel;
  stop_update_allowed: boolean;
  reason_codes: string[];
}

export interface StopProtectionResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  positions: PositionStop[];
  volatility_locks: Record<string, unknown>[];
}

export interface CircuitBreakerRecord {
  id: string;
  type: string;
  account_id: string;
  strategy_id: string;
  reason_codes: string[];
  related_command_id: string | null;
  related_reconciliation_id: string | null;
  created_at: string | null;
  resolved: boolean;
}

export interface CircuitBreakersResponse {
  state: string;
  reason_codes: string[];
  records: CircuitBreakerRecord[];
  total_count: number;
}

// ---------- /api/structure ----------
export interface StructureZone {
  zone_id: string;
  zone_type: string;
  direction: string;
  timeframe: string;
  price_top: number;
  price_bottom: number;
  status: string;
  current_strength: number;
  filled_ratio: number;
  reason_codes: string[];
}

export interface LiquidityPool {
  pool_id: string;
  pool_type: string;
  side: string;
  price_level: number;
  current_strength: number;
  status: string;
  touched_count: number;
}

export interface StructureEvent {
  event_id: string;
  event_type: string;
  direction: string;
  price: number;
  timeframe: string;
  timestamp: string;
}

export interface MarketStructureResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  symbol: string;
  timeframe: string;
  market_regime: string;
  structure_score: number;
  zones: StructureZone[];
  liquidity_pools: LiquidityPool[];
  events: StructureEvent[];
  premium_discount: string;
}

export interface MatrixCell {
  zone_type: string;
  status: string;
  current_strength: number;
  filled_ratio: number;
  temporary_violation: boolean;
  action: string;
  reason_codes: string[];
}

export interface MatrixRow {
  timeframe: string;
  cells: Record<string, MatrixCell>;
}

export interface StructureMatrixResponse {
  state: string;
  reason_codes: string[];
  available_actions: AvailableAction[];
  symbol: string;
  base_timeframe: string;
  rows: MatrixRow[];
}

// ---------- /api/v2/manipulation ----------
export interface ManipulationScore {
  id: string;
  symbol: string;
  timeframe: string;
  manipulation_score: number;
  stop_hunt_score: number;
  pump_dump_score: number;
  liquidity_trap_score: number;
  holder_concentration_score: number;
  funding_squeeze_score: number;
  risk_level: string;
  reasoning: string | null;
  created_at: string | null;
}

export interface ManipulationCaseSummary {
  id: string;
  symbol: string;
  manipulation_type: string;
  lifecycle_stage: string;
  confidence: number;
  trading_signal_action: string;
  created_at: string;
}

// ---------- /api/growth ----------
export interface TradeMetrics {
  total_trades: number;
  win_count: number;
  loss_count: number;
  breakeven_count: number;
  win_rate: number;
  total_pnl: number;
  avg_profit_pct: number;
  avg_loss_pct: number;
  max_drawdown_pct: number;
  best_trade_pct: number;
  worst_trade_pct: number;
  avg_hold_duration_hours: number;
  profit_factor: number;
  symbols_traded: string[];
}

export interface GrowthReport {
  id: string;
  report_type: string;
  strategy_run_id: string | null;
  strategy_version_id: string | null;
  period_start: string | null;
  period_end: string | null;
  metrics: Partial<TradeMetrics>;
}

export interface StrategyCandidate {
  id: string;
  source_growth_report_id: string | null;
  candidate_dsl_hash: string;
  status: string;
  rationale: string | null;
  dsl_valid: boolean;
  auto_execute: boolean;
  created_at: string | null;
}

export interface FailureCluster {
  cluster_name: string;
  label: string;
  trade_count: number;
  total_loss: number;
  avg_loss_pct: number;
  suggested_fix: string;
  severity: string;
}

export interface RegimeFailureCell {
  regime: string;
  failure_type: string;
  count: number;
  total_loss: number;
}

export interface FailureClusteringResponse {
  state: string;
  reason_codes: string[];
  total_loss_trades: number;
  total_loss_amount: number;
  clusters: FailureCluster[];
  regime_matrix: RegimeFailureCell[];
  common_reject_reasons: Record<string, unknown>[];
  labels: string[];
}

// ---------- AI 研究 / Agent / 情绪 / 系统 ----------
export interface AIResearchRun {
  id: number;
  symbol: string;
  asset_type: string;
  analysis_date: string;
  provider: string;
  status: string;
  rating: string | null;
  confidence: number | null;
  final_decision: string | null;
  error_message: string | null;
  started_at: string | null;
  completed_at: string | null;
}

export interface AgentProfile {
  id: number;
  name: string;
  kind: string;
  status: string;
  description: string | null;
  runtime_type: string;          // native | qoder | claude-code
  model: string | null;
  cwd: string | null;
  permission_mode: string;       // readonly | approval | auto
  allowed_tools: string[];
  max_turns: number;
  trigger_type: string;          // manual | schedule | event
  output_target: string;         // inbox | signals | growth
  system_prompt: string | null;
  last_heartbeat_at: string | null;
  created_at?: string | null;
}

export interface AgentTask {
  task_id: string;
  agent_id: number;
  runtime_type: string;
  symbol: string;
  status: string;
  error_code?: string | null;
  error_message?: string | null;
  created_at: string | null;
  completed_at: string | null;
}

export interface StrategyRunView {
  id: string;
  strategy_version_id: string;
  mode: string;
  status: string;
  started_at: string | null;
  stopped_at: string | null;
  created_at: string;
}

export interface AdminProvider {
  id: string | number;
  name?: string;
  kind?: string;
  status?: string;
  enabled?: boolean;
  [key: string]: unknown;
}

export interface SystemSettingView {
  key: string;
  value: unknown;
  description?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface SentimentMarket {
  [key: string]: unknown;
}

// ---------- /api/risk/rules ----------
export interface RiskRules {
  daily_loss_limit: number;
  weekly_loss_limit: number;
  consecutive_losses_limit: number;
  max_drawdown: number;
  correlation_threshold: number;
  kill_switch: { threshold: number; active: boolean };
}

export interface RiskRulesUpdate {
  daily_loss_limit?: number;
  weekly_loss_limit?: number;
  consecutive_losses_limit?: number;
  max_drawdown?: number;
  correlation_threshold?: number;
  kill_switch_active?: boolean;
}

// ---------- /api/trading ----------
export interface TradingCommandResponse {
  state: string;
  reason_codes: string[];
  available_actions: Record<string, unknown>[];
  command_id?: string;
  command_status?: string;
  idempotency_key?: string;
  message?: string;
}

export interface StartLiveSmallResponse {
  state: string;
  reason_codes: string[];
  available_actions: Record<string, unknown>[];
  command_id?: string;
  command_status?: string;
  can_proceed: boolean;
  live_small_enabled: boolean;
  preconditions?: Record<string, unknown>;
  risk_errors?: Record<string, unknown>[];
  config_preview?: Record<string, unknown>;
}

export interface DisableAutoResponse {
  state: string;
  reason_codes: string[];
  available_actions: Record<string, unknown>[];
  stopped_dryruns: number;
  command_ids: string[];
  firewall_active: boolean;
}
