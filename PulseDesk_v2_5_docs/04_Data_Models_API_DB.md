# PulseDesk v2.0 数据模型、API 与数据库设计

## 1. Pydantic / TypeScript 共用模型原则

后端 Pydantic Schema 与前端 TypeScript 类型必须一一对应。  
任意字段变更必须同步修改：

```text
backend/signal_center/schemas.py
frontend/types/signal.ts
docs/04_Data_Models_API_DB.md
```

## 2. Signal Schema

### 2.1 TypeScript

```ts
export type SignalSourceType =
  | 'tradingagents'
  | 'ai_trader_agent'
  | 'finbert'
  | 'timesfm'
  | 'chronos'
  | 'qlib'
  | 'freqai'
  | 'technical'
  | 'onchain'
  | 'manipulation'
  | 'rag'
  | 'manual'
  | 'dag_strategy';

export type SignalDirection = 'long' | 'short' | 'hold' | 'risk' | 'block';
export type RiskLevel = 'low' | 'medium' | 'high' | 'extreme';
export type SignalStatus = 'draft' | 'active' | 'expired' | 'archived' | 'invalid';

export interface SignalPermission {
  can_show: boolean;
  can_backtest: boolean;
  can_paper_trade: boolean;
  can_live_trade: boolean;
  requires_human_confirm: boolean;
}

export interface SignalEvidence {
  type: 'text' | 'url' | 'metric' | 'chart' | 'order' | 'wallet' | 'news';
  title: string;
  content: string;
  url?: string;
  weight?: number;
}

export interface Signal {
  id: string;
  source_type: SignalSourceType;
  source_name: string;
  symbol: string;
  market: 'crypto' | 'stock' | 'a_share' | 'futures' | 'gold' | 'etf';
  exchange?: string;
  timeframe: string;
  direction: SignalDirection;
  confidence: number;
  score: number;
  risk_level: RiskLevel;
  target_price?: number;
  stop_loss?: number;
  take_profit?: number;
  reasoning: string;
  evidence: SignalEvidence[];
  expires_at: string;
  permission: SignalPermission;
  status: SignalStatus;
  created_at: string;
  updated_at: string;
}
```

### 2.2 Pydantic

```python
from enum import Enum
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime

class SignalSourceType(str, Enum):
    tradingagents = "tradingagents"
    ai_trader_agent = "ai_trader_agent"
    finbert = "finbert"
    timesfm = "timesfm"
    chronos = "chronos"
    qlib = "qlib"
    freqai = "freqai"
    technical = "technical"
    onchain = "onchain"
    manipulation = "manipulation"
    rag = "rag"
    manual = "manual"
    dag_strategy = "dag_strategy"

class SignalPermission(BaseModel):
    can_show: bool = True
    can_backtest: bool = True
    can_paper_trade: bool = False
    can_live_trade: bool = False
    requires_human_confirm: bool = True

class SignalEvidence(BaseModel):
    type: Literal["text", "url", "metric", "chart", "order", "wallet", "news"]
    title: str
    content: str
    url: Optional[str] = None
    weight: Optional[float] = None

class SignalCreate(BaseModel):
    source_type: SignalSourceType
    source_name: str
    symbol: str
    market: Literal["crypto", "stock", "a_share", "futures", "gold", "etf"]
    exchange: Optional[str] = None
    timeframe: str
    direction: Literal["long", "short", "hold", "risk", "block"]
    confidence: float = Field(ge=0, le=1)
    score: float = Field(ge=0, le=5)
    risk_level: Literal["low", "medium", "high", "extreme"]
    target_price: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    reasoning: str
    evidence: list[SignalEvidence] = []
    expires_at: datetime
    permission: SignalPermission = SignalPermission()

class SignalRead(SignalCreate):
    id: str
    status: Literal["draft", "active", "expired", "archived", "invalid"]
    created_at: datetime
    updated_at: datetime
```

## 3. Strategy Schema

```ts
export type StrategySource =
  | 'manual'
  | 'ai_chat'
  | 'tradingagents'
  | 'rag'
  | 'freqai'
  | 'canvas'
  | 'signal_center'
  | 'order_intelligence';

export type StrategyStatus =
  | 'draft'
  | 'validated'
  | 'backtested'
  | 'paper_running'
  | 'paper_passed'
  | 'live_pending'
  | 'live_small'
  | 'paused'
  | 'archived'
  | 'rejected';

export interface RiskPolicy {
  max_position_pct_per_trade: number;
  max_total_position_pct: number;
  max_daily_loss_pct: number;
  max_consecutive_losses: number;
  cooldown_after_loss_minutes: number;
  max_slippage_pct: number;
  max_manipulation_score: number;
  allow_leverage: boolean;
  allow_live_trade: boolean;
}

export interface Strategy {
  id: string;
  name: string;
  source: StrategySource;
  status: StrategyStatus;
  market: string;
  exchange: string;
  symbol: string;
  timeframe: string;
  version: number;
  risk_policy: RiskPolicy;
  signal_ids: string[];
  dag_json?: unknown;
  freqtrade_strategy_path?: string;
  created_at: string;
  updated_at: string;
}
```

## 4. TradeIntent

```ts
export interface TradeIntent {
  id: string;
  source_signal_ids: string[];
  strategy_id?: string;
  agent_id?: string;
  symbol: string;
  side: 'buy' | 'sell' | 'short' | 'cover';
  position_pct: number;
  mode: 'backtest' | 'paper' | 'dry_run' | 'live_small';
  reasoning: string;
  created_at: string;
}
```

## 5. RiskDecision

```ts
export interface RiskDecision {
  id: string;
  intent_id: string;
  decision: 'ALLOW' | 'REDUCE_SIZE' | 'REJECT' | 'PAPER_ONLY' | 'HUMAN_CONFIRM';
  final_position_pct: number;
  risk_codes: string[];
  reasoning: string;
  created_at: string;
}
```

## 6. ManipulationScore

```ts
export interface ManipulationScore {
  id: string;
  symbol: string;
  timeframe: string;
  manipulation_score: number;
  stop_hunt_score: number;
  holder_concentration_score: number;
  liquidity_trap_score: number;
  pump_dump_score: number;
  funding_squeeze_score: number;
  risk_level: 'low' | 'medium' | 'high' | 'extreme';
  reasoning: string;
  evidence: SignalEvidence[];
  created_at: string;
}
```

## 7. PostgreSQL Tables

```sql
CREATE TABLE signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type TEXT NOT NULL,
    source_name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    market TEXT NOT NULL,
    exchange TEXT,
    timeframe TEXT NOT NULL,
    direction TEXT NOT NULL,
    confidence NUMERIC(5,4) NOT NULL,
    score NUMERIC(5,2) NOT NULL,
    risk_level TEXT NOT NULL,
    target_price NUMERIC(20,8),
    stop_loss NUMERIC(20,8),
    take_profit NUMERIC(20,8),
    reasoning TEXT NOT NULL,
    permission JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE signal_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    signal_id UUID REFERENCES signals(id) ON DELETE CASCADE,
    evidence_type TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    url TEXT,
    weight NUMERIC(5,4),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE strategies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    source TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    market TEXT NOT NULL,
    exchange TEXT NOT NULL,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    risk_policy JSONB NOT NULL,
    signal_ids JSONB DEFAULT '[]',
    dag_json JSONB,
    freqtrade_strategy_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE trade_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_signal_ids JSONB NOT NULL,
    strategy_id UUID REFERENCES strategies(id),
    agent_id UUID,
    symbol TEXT NOT NULL,
    side TEXT NOT NULL,
    position_pct NUMERIC(6,4) NOT NULL,
    mode TEXT NOT NULL,
    reasoning TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE risk_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intent_id UUID REFERENCES trade_intents(id),
    decision TEXT NOT NULL,
    final_position_pct NUMERIC(6,4),
    risk_codes JSONB NOT NULL,
    reasoning TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE execution_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID REFERENCES strategies(id),
    freqtrade_run_id UUID,
    trade_intent_id UUID REFERENCES trade_intents(id),
    risk_decision_id UUID REFERENCES risk_decisions(id),
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE manipulation_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    scores JSONB NOT NULL,
    risk_level TEXT NOT NULL,
    reasoning TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE feature_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT,
    strategy_id UUID REFERENCES strategies(id),
    symbol TEXT NOT NULL,
    snapshot_time TIMESTAMPTZ NOT NULL,
    features JSONB NOT NULL,
    label TEXT,
    pnl_pct NUMERIC(10,6),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE strategy_candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL,
    hypothesis TEXT NOT NULL,
    strategy_type TEXT NOT NULL,
    status TEXT NOT NULL,
    config JSONB NOT NULL,
    backtest_metrics JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 8. Redis Keys

```text
signal:latest:{symbol}
signal:source:{source_type}:{symbol}
market:ohlcv:{symbol}:{timeframe}
feature:technical:{symbol}:{timeframe}
feature:bottom:{symbol}:{timeframe}
feature:rolling_low:{symbol}:{timeframe}
feature:manipulation:{symbol}
risk:latest:{symbol}
agent:state:{agent_id}
strategy:status:{strategy_id}
freqtrade:run:{run_id}
```

TTL 建议：

| Key | TTL |
|---|---:|
| market:ohlcv:1m | 90s |
| market:ohlcv:1h | 90min |
| feature:technical | 1.5x timeframe |
| signal:latest | 按 Signal.expires_at |
| feature:manipulation | 15min |
| risk:latest | 5min |
| agent:state | 10min |
| strategy:status | 24h |

## 9. REST API

### Signal

```text
POST   /api/signals
GET    /api/signals
GET    /api/signals/{id}
POST   /api/signals/{id}/archive
POST   /api/signals/{id}/publish-to-strategy
POST   /api/signals/{id}/observe-paper
POST   /api/signals/aggregate
POST   /api/signals/conflict-check
```

### Research

```text
POST   /api/research/tradingagents/run
GET    /api/research/reports
GET    /api/research/reports/{id}
POST   /api/research/{id}/publish-signal
POST   /api/research/{id}/create-strategy-draft
```

### Strategy

```text
POST   /api/strategies
GET    /api/strategies
GET    /api/strategies/{id}
POST   /api/strategies/{id}/validate
POST   /api/strategies/{id}/backtest
POST   /api/strategies/{id}/paper-run
POST   /api/strategies/{id}/pause
POST   /api/strategies/{id}/archive
```

### Freqtrade

```text
POST   /api/freqtrade/config/generate
POST   /api/freqtrade/strategy/generate
POST   /api/freqtrade/docker/start
POST   /api/freqtrade/docker/stop
POST   /api/freqtrade/backtest/run
GET    /api/freqtrade/orders
GET    /api/freqtrade/status
WS     /api/freqtrade/events
```

### Risk

```text
POST   /api/risk/evaluate
GET    /api/risk/events
GET    /api/risk/correlation
GET    /api/risk/manipulation/{symbol}
POST   /api/risk/emergency-stop
POST   /api/risk/emergency-resume
```

### Growth

```text
POST   /api/growth/daily-review
POST   /api/growth/order-mining
GET    /api/growth/reports
GET    /api/growth/candidates
POST   /api/growth/candidates/{id}/backtest
POST   /api/growth/candidates/{id}/paper-run
```

---

# v2.1 数据模型补强

## 10. Signal 生命周期增强

### 10.1 SignalStatus

```ts
export type SignalStatus =
  | 'draft'
  | 'pending'
  | 'active'
  | 'used_in_strategy'
  | 'observed_in_paper'
  | 'rejected'
  | 'expired'
  | 'executed'
  | 'archived'
  | 'invalid';
```

### 10.2 TriggerCondition 与 CurrentState

```ts
export interface TriggerCondition {
  type: 'threshold' | 'pattern' | 'agent_opinion' | 'forecast' | 'risk_rule' | 'manual';
  expression: string;
  params: Record<string, unknown>;
  readable: string;
}

export interface CurrentStateSnapshot {
  price?: number;
  volume?: number;
  indicators?: Record<string, number>;
  sentiment?: Record<string, unknown>;
  onchain?: Record<string, unknown>;
  funding?: Record<string, unknown>;
  manipulation?: Record<string, unknown>;
  timestamp: string;
}

export interface SignalLifecycleEvent {
  status: SignalStatus;
  reason: string;
  actor: 'system' | 'user' | 'agent' | 'risk_engine';
  created_at: string;
}
```

### 10.3 Signal v2.1 TypeScript

```ts
export interface SignalV21 extends Signal {
  trigger_condition: TriggerCondition;
  current_state: CurrentStateSnapshot;
  ttl_seconds: number;
  conflict_group_id?: string;
  parent_signal_ids?: string[];
  lifecycle_events: SignalLifecycleEvent[];
  provider_trace?: ProviderTrace;
}
```

## 11. ProviderTrace / AI 服务路由

```ts
export interface ProviderTrace {
  provider_id: string;
  provider_type: 'openai' | 'deepseek' | 'ollama' | 'local_model';
  model_name: string;
  model_version?: string;
  prompt_version?: string;
  latency_ms?: number;
  cost_usd?: number;
  fallback_used: boolean;
}

export interface AIProviderRoutingRule {
  task_type:
    | 'research_deep'
    | 'research_fast'
    | 'rag_summary'
    | 'sentiment'
    | 'prediction'
    | 'attribution'
    | 'agent_signal';
  primary_provider_id: string;
  fallback_provider_ids: string[];
  max_latency_ms: number;
  on_failure: 'fallback' | 'disable_module' | 'degrade_permission';
}
```

## 12. Freqtrade 状态模型

```ts
export type FreqtradeRunMode = 'backtest' | 'dry_run' | 'live_small';
export type FreqtradeRunStatus =
  | 'queued'
  | 'config_generated'
  | 'container_starting'
  | 'running'
  | 'degraded'
  | 'stopping'
  | 'stopped'
  | 'failed'
  | 'completed';

export interface FreqtradeRun {
  id: string;
  strategy_id: string;
  strategy_version: number;
  mode: FreqtradeRunMode;
  container_name?: string;
  config_path: string;
  rules_path: string;
  fixed_strategy_template: 'PulseDeskUniversalStrategy.py';
  status: FreqtradeRunStatus;
  heartbeat_at?: string;
  last_error?: string;
  started_at?: string;
  stopped_at?: string;
  created_at: string;
}
```

## 13. 资金池模型

```ts
export type CapitalPoolType = 'main' | 'paper' | 'high_risk_hunt' | 'live_small';

export interface CapitalPool {
  id: string;
  name: string;
  pool_type: CapitalPoolType;
  currency: 'USDT' | 'USD' | 'BTC' | 'ETH';
  total_budget: number;
  max_position_pct_per_trade: number;
  max_total_exposure_pct: number;
  max_daily_loss_pct: number;
  max_drawdown_pct: number;
  allow_leverage: boolean;
  allow_auto_trade: boolean;
  requires_human_confirm: boolean;
  emergency_stop: boolean;
  created_at: string;
  updated_at: string;
}
```

### 13.1 高风险猎币资金池默认配置

```json
{
  "pool_type": "high_risk_hunt",
  "total_budget": 1000,
  "max_position_pct_per_trade": 0.005,
  "max_total_exposure_pct": 0.03,
  "max_daily_loss_pct": 0.01,
  "max_drawdown_pct": 0.08,
  "allow_leverage": false,
  "allow_auto_trade": false,
  "requires_human_confirm": true,
  "emergency_stop": false
}
```

## 14. 操控雷达数据源模型

```ts
export interface ManipulationDataSource {
  id: string;
  source_type:
    | 'ohlcv'
    | 'funding_rate'
    | 'open_interest'
    | 'liquidation'
    | 'orderbook'
    | 'wallet_distribution'
    | 'exchange_flow'
    | 'news_social';
  provider: 'ccxt' | 'exchange_api' | 'dune' | 'etherscan' | 'solscan' | 'nansen' | 'arkham' | 'glassnode' | 'cryptoquant' | 'manual_csv';
  enabled: boolean;
  cost_level: 'free' | 'paid' | 'expensive';
  latency_level: 'realtime' | 'near_realtime' | 'delayed' | 'manual';
  coverage: string[];
  last_sync_at?: string;
}
```

## 15. SQL 增量表

```sql
CREATE TABLE freqtrade_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID REFERENCES strategies(id),
    strategy_version INT NOT NULL,
    mode TEXT NOT NULL,
    container_name TEXT,
    config_path TEXT NOT NULL,
    rules_path TEXT NOT NULL,
    rule_package_hash TEXT NOT NULL,
    fixed_strategy_template TEXT NOT NULL DEFAULT 'PulseDeskUniversalStrategy.py',
    status TEXT NOT NULL,
    heartbeat_at TIMESTAMPTZ,
    last_error TEXT,
    started_at TIMESTAMPTZ,
    stopped_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE capital_pools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    pool_type TEXT NOT NULL,
    currency TEXT NOT NULL,
    total_budget NUMERIC(20,8) NOT NULL,
    max_position_pct_per_trade NUMERIC(8,6) NOT NULL,
    max_total_exposure_pct NUMERIC(8,6) NOT NULL,
    max_daily_loss_pct NUMERIC(8,6) NOT NULL,
    max_drawdown_pct NUMERIC(8,6) NOT NULL,
    allow_leverage BOOLEAN NOT NULL DEFAULT FALSE,
    allow_auto_trade BOOLEAN NOT NULL DEFAULT FALSE,
    requires_human_confirm BOOLEAN NOT NULL DEFAULT TRUE,
    emergency_stop BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE signal_lifecycle_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    signal_id UUID REFERENCES signals(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    reason TEXT NOT NULL,
    actor TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_provider_traces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_type TEXT NOT NULL,
    object_id UUID NOT NULL,
    provider_id TEXT NOT NULL,
    provider_type TEXT NOT NULL,
    model_name TEXT NOT NULL,
    model_version TEXT,
    prompt_version TEXT,
    latency_ms INT,
    cost_usd NUMERIC(12,6),
    fallback_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

# v2.2 新增数据模型

## 1. InferenceJob

```json
{
  "id": "job_xxx",
  "task_type": "llm_research|finbert_sentiment|timesfm_forecast|chronos_forecast|shap_explain",
  "priority": "low|normal|high|critical",
  "model_provider": "ollama|openai|deepseek|local_finbert|timesfm|chronos|shap",
  "model_name": "qwen2.5:7b",
  "resource_class": "lightweight|medium|heavyweight",
  "gpu_required": true,
  "estimated_vram_mb": 8000,
  "status": "queued|loading_model|running|succeeded|failed|cancelled|timeout|degraded",
  "input_ref": "storage://inference_inputs/job_xxx.json",
  "output_ref": "storage://inference_outputs/job_xxx.json",
  "timeout_sec": 300,
  "created_at": "2026-06-02T10:00:00Z",
  "started_at": null,
  "finished_at": null,
  "error": null
}
```

## 2. StrategyRuleDSL

```json
{
  "schema_version": "2.2",
  "strategy_id": "strategy_xxx",
  "strategy_type": "bottom_accumulation|rolling_low_ladder|signal_combo|manual_rule",
  "symbol": "BTC/USDT",
  "timeframe": "1h",
  "indicators": [
    {"name": "rsi", "period": 14},
    {"name": "rolling_low", "window": 90}
  ],
  "entry_rules": {
    "operator": "AND",
    "conditions": [
      {"left": "price_percentile_90d", "op": "<", "right": 0.15},
      {"left": "sideways_days", "op": ">=", "right": 14}
    ]
  },
  "exit_rules": {
    "operator": "OR",
    "conditions": [
      {"left": "rsi", "op": ">", "right": 72},
      {"left": "stop_loss_pct", "op": "<=", "right": -0.06}
    ]
  },
  "risk": {
    "position_pct": 0.02,
    "max_total_position_pct": 0.08,
    "stoploss": -0.06,
    "trailing_stop": true,
    "max_open_trades": 2
  },
  "permissions": {
    "can_backtest": true,
    "can_dry_run": true,
    "can_live": false,
    "requires_human_confirm": true
  }
}
```

## 3. MCPAuditLog

```json
{
  "id": "mcp_log_xxx",
  "client_name": "claude_desktop|cursor|chatgpt|unknown",
  "tool_name": "get_latest_signals",
  "arguments_hash": "sha256_xxx",
  "result_count": 10,
  "status": "succeeded|failed|denied",
  "denied_reason": null,
  "created_at": "2026-06-02T10:00:00Z"
}
```

## 4. FreqtradeConnectionState

```json
{
  "run_id": "ft_run_xxx",
  "state": "healthy|connection_lost|pulse_degraded|freqtrade_native_guard_only|reconciliating|failed",
  "rest_ok": true,
  "websocket_ok": true,
  "docker_ok": true,
  "has_open_positions": false,
  "native_risk_validated": true,
  "last_seen_at": "2026-06-02T10:00:00Z",
  "reason": null
}
```

---

# v2.2 PostgreSQL 分区建议

`signals` 主表按月分区：

```sql
CREATE TABLE signals (
    id UUID NOT NULL,
    source_type TEXT NOT NULL,
    source_name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    market TEXT NOT NULL,
    timeframe TEXT,
    direction TEXT NOT NULL,
    confidence NUMERIC(5,4),
    score NUMERIC(8,4),
    risk_level TEXT,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    summary TEXT,
    payload JSONB NOT NULL,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
```

新增表：

```sql
CREATE TABLE inference_jobs (...);
CREATE TABLE model_runtime_states (...);
CREATE TABLE strategy_rule_dsl_versions (...);
CREATE TABLE mcp_audit_logs (...);
CREATE TABLE signal_archival_jobs (...);
CREATE TABLE freqtrade_connection_states (...);
```

---

# v2.2 API 补充

## Inference Queue API

```text
POST /api/inference/jobs
GET  /api/inference/jobs
GET  /api/inference/jobs/{id}
POST /api/inference/jobs/{id}/cancel
GET  /api/inference/runtime-state
```

## Strategy DSL API

```text
POST /api/strategies/{id}/dsl/validate
POST /api/strategies/{id}/dsl/compile
GET  /api/strategies/{id}/dsl
```

## MCP 管理 API

```text
GET  /api/mcp/status
GET  /api/mcp/audit-logs
POST /api/mcp/rotate-token
```

## Data Vacuum API

```text
POST /api/admin/data-vacuum/run
GET  /api/admin/data-vacuum/jobs
```

---

# v2.3 Addendum — Provider Trace / Cloud Routing Data Models

## 1. ProviderTrace

```json
{
  "provider": "openai|anthropic|deepseek|ollama|replicate|runpod|private_model_server",
  "model": "string",
  "task_type": "research_deep_dive|agent_debate|rag_summary|sentiment_classification|strategy_draft_generation|signal_reasoning|prediction_timeseries|shap_attribution|manipulation_explanation",
  "request_id": "string|null",
  "input_hash": "sha256:string",
  "output_hash": "sha256:string",
  "schema_version": "string",
  "latency_ms": 0,
  "estimated_cost_usd": 0.0,
  "privacy_level": "public|medium|sensitive|local_only",
  "status": "success|failed|timeout|degraded",
  "error_code": "string|null",
  "created_at": "datetime"
}
```

## 2. Signal.provider_trace

`signals` 表新增字段：

```text
provider_trace JSONB NULL
privacy_level TEXT DEFAULT 'medium'
generation_mode TEXT DEFAULT 'cloud|remote|local|manual'
```

约束：

```text
1. cloud / remote 生成的 Signal 必须有 provider_trace。
2. manual / dag_strategy 可以为空。
3. provider_trace.input_hash 只能保存 hash，不能保存原文。
4. provider_trace 不允许包含 API Key、secret、token。
```

## 3. AI Provider Tables

```sql
CREATE TABLE ai_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_type TEXT NOT NULL,
    display_name TEXT NOT NULL,
    base_url TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    default_for_tasks TEXT[] NOT NULL DEFAULT '{}',
    privacy_allowed_levels TEXT[] NOT NULL DEFAULT '{public,medium}',
    max_daily_cost_usd NUMERIC(12,4),
    timeout_seconds INTEGER NOT NULL DEFAULT 60,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_provider_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES ai_providers(id),
    task_type TEXT NOT NULL,
    model TEXT,
    latency_ms INTEGER,
    estimated_cost_usd NUMERIC(12,6),
    status TEXT NOT NULL,
    error_code TEXT,
    input_hash TEXT,
    output_hash TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 4. Remote Model Jobs

```sql
CREATE TABLE remote_model_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_type TEXT NOT NULL,
    task_type TEXT NOT NULL,
    symbol TEXT,
    status TEXT NOT NULL DEFAULT 'queued',
    request_payload_hash TEXT NOT NULL,
    result_signal_id UUID NULL,
    error_code TEXT NULL,
    started_at TIMESTAMPTZ NULL,
    finished_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 5. API Additions

```text
GET    /api/ai/providers
POST   /api/ai/providers
PATCH  /api/ai/providers/{id}
GET    /api/ai/providers/usage
POST   /api/ai/route/preview
POST   /api/ai/tasks/run
GET    /api/ai/tasks/{job_id}
POST   /api/ai/privacy/redact-preview
```

## 6. TypeScript Types

```ts
export type ProviderType =
  | 'openai'
  | 'anthropic'
  | 'deepseek'
  | 'ollama'
  | 'replicate'
  | 'runpod'
  | 'private_model_server';

export type AITaskType =
  | 'research_deep_dive'
  | 'agent_debate'
  | 'rag_summary'
  | 'sentiment_classification'
  | 'strategy_draft_generation'
  | 'signal_reasoning'
  | 'prediction_timeseries'
  | 'shap_attribution'
  | 'manipulation_explanation';

export interface ProviderTrace {
  provider: ProviderType;
  model: string;
  task_type: AITaskType;
  request_id?: string | null;
  input_hash: string;
  output_hash?: string | null;
  schema_version: string;
  latency_ms: number;
  estimated_cost_usd?: number | null;
  privacy_level: 'public' | 'medium' | 'sensitive' | 'local_only';
  status: 'success' | 'failed' | 'timeout' | 'degraded';
  error_code?: string | null;
  created_at: string;
}
```


---

# v2.3.2 Data Model Additions

## signal_archive_index

```sql
CREATE TABLE signal_archive_index (
    signal_id UUID PRIMARY KEY,
    archive_type TEXT NOT NULL CHECK (archive_type IN ('sqlite', 'parquet')),
    archive_uri TEXT NOT NULL,
    partition_month TEXT NOT NULL,
    checksum TEXT,
    archived_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## signal_reference_snapshots

```sql
CREATE TABLE signal_reference_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_type TEXT NOT NULL,
    reference_id UUID NOT NULL,
    signal_id UUID NOT NULL,
    snapshot_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## reconciliation_events

```sql
CREATE TABLE reconciliation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id UUID,
    previous_state TEXT NOT NULL,
    next_state TEXT NOT NULL,
    mismatch_count INTEGER NOT NULL DEFAULT 0,
    patched_orders INTEGER NOT NULL DEFAULT 0,
    patched_positions INTEGER NOT NULL DEFAULT 0,
    unresolved_items JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## v2.4 架构审计补丁：数据库结构升级

### 1. Signal 表拆分

`signals` 表只保留轻量索引字段。大文本、证据、ProviderTrace、生命周期事件拆表：

```text
signals
signal_payloads
signal_evidence
signal_provider_traces
signal_lifecycle_events
signal_snapshots
```

开发时必须参考 `10_Database_ERD_v2_4.md`，不得继续把 reasoning / raw_output / evidence 全部塞进 `signals` JSONB。

### 2. Strategy 核心表

策略必须拆成：

```text
strategies                策略身份
strategy_versions         策略版本
strategy_rule_dsl_versions DSL 版本
strategy_runs             PulseDesk 运行实例
freqtrade_runs            Freqtrade 容器/进程运行实例
```

### 3. TradeIntent 快照

`trade_intents` 不能只保存 `source_signal_ids`。创建 TradeIntent 时必须写入：

```text
trade_intent_signal_snapshots
feature_snapshot_id
```

用于保证几个月后 Growth Engine 仍能还原触发依据。

### 4. FeatureSnapshot

新增 `feature_snapshots`，作为订单学习、SHAP、策略进化的基础事实。每次 TradeIntent 生成前应保存或引用一份 feature snapshot。

### 5. Execution Ledger

新增 `execution_ledger_events`，不可变 append-only。Freqtrade 事件、RiskDecision、对账事件都必须写入。

### 6. 统一 Repository

上层模块禁止直接 join 热表。必须通过：

```python
SignalRepository
StrategyRepository
ExecutionLedgerRepository
FeatureSnapshotRepository
```

冷数据查询走 Data Federation Layer。


---

## v2.5 收口说明

本文件中若仍存在与 `00_MASTER_ARCHITECTURE_DECISION_v2_5.md` 冲突的旧描述，以 v2.5 Master Architecture Decision 为准。特别是：禁止开放式 Strategy.py 生成；禁止 Canvas 生成 Python；Freqtrade 只加载固定 `PulseDeskUniversalStrategy.py` 并读取 StrategyRuleDSL RulePackage。
