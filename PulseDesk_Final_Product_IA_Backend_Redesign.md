# PulseDesk 最终产品级页面架构与后端对接重构方案

> 文档定位：PulseDesk 最终页面信息架构、后端服务重构、接口对接与新增功能设计文档  
> 适用范围：macOS Native App + WKWebView + React Flow Canvas + Python/FastAPI 后端 + Redis + PostgreSQL + Freqtrade/CCXT  
> 核心目标：完全按照产品级交易运行控制台重新设计页面与后端对接，不再以现有后端功能页为约束。  
> 更新时间：2026-06-05

---

## 0. 最终结论

PulseDesk 最终应采用以下产品级信息架构：

```text
OVERVIEW
- 总览 Dashboard
- 实盘准入 Live Readiness

STRATEGY
- 策略工作台
- 策略画布
- 回测 / 模拟

STRUCTURE
- 市场结构
- 结构矩阵
- 操纵雷达

EXECUTION
- 执行中心
- 订单 / 持仓
- 对账总线

RISK
- 风控中心
- 止损保护
- 熔断记录

AI RESEARCH
- AI 投研室
- Agent 平台
- 信号中心
- 市场情绪

GROWTH
- 复盘成长
- 失败聚类
- 策略优化

SYSTEM
- 服务管理
- 数据源管理
- 系统设置
```

这套结构不是简单菜单调整，而是把 PulseDesk 从：

```text
AI 功能集合 / 后端功能映射式 App
```

升级为：

```text
AI 结构化自动交易运行控制台
```

后端也必须同步调整为面向前端页面的聚合式能力架构：

```text
Domain Services
  ↓
Runtime State / Event Ledger / Analytics Store
  ↓
Page ViewModel API
  ↓
macOS App 页面
```

---

# 1. 最终页面主线

PulseDesk 的最终用户路径应是：

```text
1. 打开 Dashboard，看账户、策略、风险、系统状态。
2. 进入 Live Readiness，确认当前是否允许实盘。
3. 在 Strategy 创建、编辑、回测策略。
4. 在 Structure 检查市场结构和流动性陷阱。
5. 在 Execution 监控 Freqtrade、订单、持仓、对账。
6. 在 Risk 查看拒单、止损保护、熔断。
7. 在 AI Research 获取新闻、Agent、信号、情绪解释。
8. 在 Growth 复盘失败模式并生成策略优化候选。
9. 在 System 管理服务、数据源、交易所和模型配置。
```

核心逻辑：

```text
先判断能不能交易
再判断策略是否有效
再判断市场结构是否支持
再判断执行链路是否可靠
再判断账户风险是否允许
最后才进入自动交易
```

---

# 2. 后端总体重构原则

## 2.1 后端不再按页面简单拆服务

不要让后端变成：

```text
DashboardService
StrategyPageService
RiskPageService
```

而应该保留清晰领域服务：

```text
Strategy Service
Canvas Service
Structure Service
Decision Service
Risk Service
Execution Service
Reconciliation Service
AI Research Service
Signal Service
Growth Service
System Service
Data Source Service
```

然后新增一层：

```text
Page ViewModel API / BFF Layer
```

负责把多个领域服务聚合成页面所需数据。

---

## 2.2 推荐后端分层

```text
┌──────────────────────────────────────────────┐
│ macOS App / WebView Frontend                  │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│ Page ViewModel API / BFF Layer                │
│ 面向页面聚合数据、状态、reason_codes、actions  │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│ Domain Services                               │
│ Strategy / Structure / Risk / Execution / AI  │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│ Runtime State + Event Store                   │
│ Redis / In-Memory / PostgreSQL / Ledger       │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│ External Engines                              │
│ Freqtrade / CCXT / Exchange / AI Providers    │
└──────────────────────────────────────────────┘
```

---

## 2.3 后端必须输出三类数据

所有页面都应围绕三类数据设计：

### 1. State 当前状态

```text
当前是否健康
当前是否允许交易
当前是否持仓
当前是否锁定
当前是否对账中
```

### 2. Reason 原因解释

```text
为什么允许
为什么拒绝
为什么降仓
为什么锁止损
为什么不能实盘
```

统一字段：

```json
{
  "reason_codes": [
    "snapshot_fresh",
    "freqtrade_healthy",
    "ai_cache_soft_expired_reduce_size"
  ]
}
```

### 3. Action 可执行动作

```text
启动
停止
回测
模拟
熔断
重新对账
强制刷新交易所状态
进入策略详情
生成 DSL Draft
```

统一字段：

```json
{
  "available_actions": [
    {
      "type": "start_live_small",
      "enabled": true,
      "label": "启动小仓实盘"
    }
  ]
}
```

---

# 3. 页面与后端服务映射总表

| 页面 | 主要后端服务 | 关键数据源 | 是否需要聚合 API |
|---|---|---|---|
| Dashboard | Account / Strategy / Risk / Execution / System | PostgreSQL + Redis | 是 |
| Live Readiness | System / Execution / Risk / AI / DataSource | Redis + health checks | 是 |
| 策略工作台 | Strategy / Decision / Risk / Growth | PostgreSQL + Redis | 是 |
| 策略画布 | Canvas / DSL / Strategy | PostgreSQL | 是 |
| 回测 / 模拟 | Backtest / Simulation / Strategy | PostgreSQL + Data Store | 是 |
| 市场结构 | Structure / Market Data | Redis + PostgreSQL | 是 |
| 结构矩阵 | Structure / Shadow Window | Redis | 是 |
| 操纵雷达 | Structure / Orderbook / Whale / News | Redis + external data | 是 |
| 执行中心 | Execution / Freqtrade / Risk | Redis + PostgreSQL | 是 |
| 订单 / 持仓 | Execution / Exchange / Freqtrade | Exchange + PostgreSQL | 是 |
| 对账总线 | Reconciliation / Ledger / CommandBus | PostgreSQL + Redis | 是 |
| 风控中心 | Risk / Account / Decision | Redis + PostgreSQL | 是 |
| 止损保护 | Risk / Structure / Execution | Redis | 是 |
| 熔断记录 | Risk / CommandBus / Ledger | PostgreSQL | 是 |
| AI 投研室 | AI Research / News / Reports | PostgreSQL + providers | 是 |
| Agent 平台 | Agent / Task Orchestrator | PostgreSQL | 是 |
| 信号中心 | Signal / Structure / AI / Indicators | Redis + PostgreSQL | 是 |
| 市场情绪 | Sentiment / News / Social | external + PostgreSQL | 是 |
| 复盘成长 | Growth / Review / Trades | PostgreSQL | 是 |
| 失败聚类 | Growth / Analytics | PostgreSQL + analytics jobs | 是 |
| 策略优化 | Growth / Strategy / Backtest | PostgreSQL | 是 |
| 服务管理 | System / Process Manager | health checks | 是 |
| 数据源管理 | DataSource / MarketData | providers | 是 |
| 系统设置 | Settings / Account / Provider | PostgreSQL / local config | 是 |

---

# 4. OVERVIEW

---

## 4.1 总览 Dashboard

### 页面定位

Dashboard 是交易运行总控台。

它不是 AI 总控台，也不是普通首页。

它必须回答：

```text
我的账户怎么样？
今天赚亏怎么样？
现在跑了哪些策略？
有没有持仓？
有没有风险锁？
系统是否健康？
最近发生了什么关键事件？
```

### 核心功能

```text
1. Account Equity Overview
2. PnL Summary
3. Running Strategy Summary
4. Open Position Summary
5. Global Risk State
6. System Health Summary
7. Recent Decisions
8. Latest Alerts
9. Current Live Readiness State
10. Emergency Stop 快捷入口
```

### 前端组件

```text
DashboardPage
├── GlobalStatusBar
├── EquityCard
├── PnLCardGroup
├── StrategyRuntimeCard
├── PositionRiskCard
├── LiveReadinessMiniCard
├── GlobalRiskCard
├── RecentDecisionFeed
├── AlertTimeline
└── EmergencyActionBar
```

### 后端聚合接口

```http
GET /api/overview/dashboard
```

### 返回示例

```json
{
  "account": {
    "equity": 10248.32,
    "currency": "USDT",
    "today_pnl_pct": 0.012,
    "week_pnl_pct": 0.038,
    "max_drawdown_pct": 0.041
  },
  "runtime": {
    "running_strategies": 2,
    "open_positions": 3,
    "pending_orders": 1,
    "reconciling_count": 0
  },
  "risk": {
    "global_state": "normal",
    "daily_loss_remaining_pct": 0.024,
    "weekly_loss_remaining_pct": 0.065,
    "emergency_locked": false
  },
  "system": {
    "live_readiness_state": "LIVE_SMALL_READY",
    "fast_track_latency_ms": 45,
    "redis_rtt_ms": 3,
    "freqtrade_state": "healthy",
    "exchange_state": "ok"
  },
  "recent_decisions": [
    {
      "time": "2026-06-05T10:00:00Z",
      "symbol": "BTC/USDT",
      "decision": "reduce_size",
      "reason_codes": ["ai_cache_soft_expired", "shadow_warning"]
    }
  ],
  "alerts": [
    {
      "level": "warning",
      "title": "1h Shadow OB temporary violation",
      "symbol": "BTC/USDT"
    }
  ]
}
```

### 后端改造

需要新增：

```text
OverviewAggregatorService
```

聚合：

```text
AccountService
StrategyRuntimeService
RiskService
ExecutionService
SystemHealthService
DecisionSnapshotService
AlertService
```

---

## 4.2 实盘准入 Live Readiness

### 页面定位

Live Readiness 是实盘总闸门。

它必须回答：

```text
当前是否允许启动自动交易？
只能 Paper？
可以 Live Small？
是否必须停止？
哪一项导致不可实盘？
```

### 核心功能

```text
1. Live Readiness Score
2. Readiness State
3. System Check List
4. Blocking Reasons
5. Warning Reasons
6. Start Paper / Start Live Small / Disable Trading
7. One-click System Check
```

### 状态枚举

```text
LIVE_READY
LIVE_SMALL_READY
PAPER_ONLY
RISK_LOCKED
EMERGENCY_LOCKED
NOT_READY
```

### 前端组件

```text
LiveReadinessPage
├── ReadinessScoreCard
├── ReadinessStateBanner
├── BlockingReasonList
├── SystemCheckGrid
├── ServiceLatencyPanel
├── ExchangeApiPanel
├── RuntimeSnapshotPanel
├── AIReadinessPanel
└── ReadinessActionBar
```

### 后端接口

```http
GET /api/overview/live-readiness
POST /api/overview/live-readiness/check
POST /api/trading/start-paper
POST /api/trading/start-live-small
POST /api/trading/disable-auto
```

### 返回示例

```json
{
  "score": 86,
  "state": "LIVE_SMALL_READY",
  "can_start_paper": true,
  "can_start_live_small": true,
  "can_start_full_live": false,
  "blocking_reasons": [],
  "warnings": [
    {
      "code": "exchange_api_weight_warning",
      "message": "交易所 API 权重剩余偏低"
    }
  ],
  "checks": [
    {
      "key": "fast_track_latency",
      "label": "Fast Track 延迟",
      "status": "healthy",
      "value": "45ms",
      "threshold": "<200ms"
    },
    {
      "key": "ai_cache_freshness",
      "label": "AI Risk Cache",
      "status": "healthy",
      "value": "fresh"
    }
  ]
}
```

### 后端改造

新增：

```text
LiveReadinessService
```

它根据以下服务计算得分：

```text
FastTrackHealthService
RedisHealthService
PostgresHealthService
FreqtradeHealthService
ExchangeHealthService
OrderbookHealthService
AIRiskCacheService
RiskStateService
ReconciliationService
VolatilityLockService
```

---

# 5. STRATEGY

---

## 5.1 策略工作台

### 页面定位

策略工作台管理策略生命周期。

必须回答：

```text
有哪些策略？
当前策略处于哪个版本？
当前运行状态是什么？
为什么允许 / 拒绝交易？
当前 Snapshot 是什么？
最近表现如何？
```

### 核心功能

```text
1. Strategy List
2. Strategy Detail
3. Version History
4. Runtime State
5. Runtime Snapshot
6. Risk Decision
7. Structure Summary
8. AI Risk Cache Summary
9. Recent Trades
10. Start / Stop / Backtest / Dryrun / Live Small
```

### 前端组件

```text
StrategyWorkspacePage
├── StrategyListPanel
├── StrategyDetailHeader
├── StrategyVersionSelector
├── StrategyRuntimeStatusCard
├── CurrentDecisionSnapshotCard
├── RiskDecisionCard
├── StructureSummaryCard
├── AIRiskCacheCard
├── RecentTradesTable
└── StrategyActionBar
```

### 后端接口

```http
GET /api/strategies
GET /api/strategies/{strategy_id}/workspace
POST /api/strategies/{strategy_id}/start-dryrun
POST /api/strategies/{strategy_id}/start-live-small
POST /api/strategies/{strategy_id}/stop
POST /api/strategies/{strategy_id}/clone
POST /api/strategies/{strategy_id}/archive
```

### 后端改造

StrategyService 需要提供：

```text
strategy metadata
strategy versions
strategy runtime binding
latest runtime snapshot
latest risk decision
latest structure summary
latest ai cache summary
recent trades
available actions
```

---

## 5.2 策略画布

### 页面定位

策略画布是策略意图编排器。

它输出：

```text
StrategyRuleDSL
```

而不是订单。

### 核心功能

```text
1. React Flow Canvas
2. Node Palette
3. Node Property Panel
4. DSL Preview
5. Static Validation
6. Compile to StrategyRuleDSL
7. Publish Draft
8. Version Diff
9. Template Library
```

### 节点分类

```text
Data Nodes
Indicator Nodes
Structure Nodes
AI Nodes
Decision Nodes
Defense Nodes
Risk Nodes
Execution Intent Nodes
Review Nodes
```

### 必须新增节点

```text
Liquidity Pool Node
Liquidity Sweep Node
FVG Node
Order Block Node
Structure Entry Score Node
Market Regime Filter Node
Holding Stop Protection Node
Account Risk Firewall Node
Manual Confirm Node
Runtime Snapshot Output Node
```

### 后端接口

```http
GET /api/canvas/templates
GET /api/canvas/strategies/{strategy_id}
POST /api/canvas/validate
POST /api/canvas/compile
POST /api/canvas/save-draft
POST /api/canvas/publish
GET /api/canvas/{canvas_id}/diff
```

### 后端改造

新增：

```text
CanvasService
DSLCompilerService
DSLValidationService
NodeRegistryService
StrategyVersionService
```

### DSL 校验要求

必须校验：

```text
节点输入输出类型
是否存在执行节点
是否存在风控节点
是否启用 Holding Stop Protection
是否存在 Account Risk Firewall
是否引用未定义数据源
是否存在循环
是否符合 Fast Track / Slow Track 约束
```

---

## 5.3 回测 / 模拟

### 页面定位

验证策略是否可上线。

### 核心功能

```text
1. Strategy Backtest
2. Structure Event Backtest
3. Market Regime Layered Backtest
4. Dryrun
5. Paper Trading
6. Live Small Simulation
7. Stress Test
```

### 后端接口

```http
GET /api/backtests
POST /api/backtests/run
GET /api/backtests/{backtest_id}
GET /api/backtests/{backtest_id}/trades
GET /api/backtests/{backtest_id}/structure-events
GET /api/backtests/{backtest_id}/risk-analysis
POST /api/simulations/dryrun
POST /api/simulations/paper
```

### 后端改造

BacktestService 需要支持：

```text
strategy replay
decision snapshot replay
structure event replay
market regime segmentation
volatility lock simulation
reconciliation stress simulation
```

---

# 6. STRUCTURE

---

## 6.1 市场结构

### 页面定位

市场结构页用于可视化结构防御引擎的判断。

### 核心功能

```text
1. Kline Chart
2. Liquidity Pools
3. FVG Zones
4. Order Blocks
5. BOS / CHoCH
6. Sweep Events
7. Premium / Discount Zone
8. Market Regime
9. Structure Score
```

### 后端接口

```http
GET /api/structure/market-view?symbol=BTC/USDT&timeframe=5m
GET /api/structure/zones
GET /api/structure/liquidity-pools
GET /api/structure/events
GET /api/structure/market-regime
```

### 后端改造

StructureService 需要输出标准结构对象：

```json
{
  "zone_id": "fvg_001",
  "zone_type": "fvg",
  "direction": "bullish",
  "timeframe": "1h",
  "price_top": 62000,
  "price_bottom": 61550,
  "status": "active",
  "current_strength": 0.82,
  "filled_ratio": 0.21,
  "reason_codes": ["fvg_active", "not_mitigated"]
}
```

---

## 6.2 结构矩阵

### 页面定位

结构矩阵是多周期结构状态总览。

必须独立成页，不再只嵌在策略工作台。

### 核心功能

```text
1. Multi-Timeframe Matrix
2. Shadow Window State
3. Structure Strength Heatmap
4. Filled Ratio
5. Temporary Violation
6. Shadow Structural Break
7. Action Recommendation
```

### 前端组件

```text
StructureMatrixPage
├── SymbolTimeframeSelector
├── FastTrackHealthMiniBar
├── MatrixHeatmap
├── ShadowWindowPanel
├── StructureDetailDrawer
└── ActionReasonPanel
```

### 后端接口

```http
GET /api/structure/matrix?symbol=BTC/USDT
GET /api/structure/shadow-windows?symbol=BTC/USDT
GET /api/structure/matrix/{cell_id}
```

### 返回示例

```json
{
  "symbol": "BTC/USDT",
  "base_timeframe": "5m",
  "rows": [
    {
      "timeframe": "1h_shadow",
      "cells": {
        "bullish_ob": {
          "status": "warning",
          "current_strength": 0.41,
          "temporary_violation": true,
          "action": "reduce_size",
          "reason_codes": ["shadow_low_violated_ob_bottom"]
        },
        "fvg": {
          "status": "active",
          "filled_ratio": 0.85,
          "action": "reduce_size"
        }
      }
    }
  ]
}
```

### 后端改造

新增：

```text
StructureMatrixService
ShadowWindowService
TimeframeIntegrityService
```

---

## 6.3 操纵雷达

### 页面定位

操纵雷达展示异常市场行为。

### 核心功能

```text
1. Manipulation Risk Score
2. Liquidity Sweep Alerts
3. Orderbook Void Alerts
4. Whale Movement Alerts
5. Exchange Inflow Alerts
6. Social / News Shock Alerts
7. False Breakout Alerts
```

### 后端接口

```http
GET /api/manipulation/radar
GET /api/manipulation/alerts
GET /api/orderbook/voids
GET /api/whale/events
GET /api/news/shocks
```

### 后端改造

新增或重构：

```text
ManipulationRadarService
OrderbookVoidDetector
WhaleEventService
NewsShockService
```

---

# 7. EXECUTION

---

## 7.1 执行中心

### 页面定位

执行中心是自动交易执行运行台。

### 核心功能

```text
1. Running Sessions
2. Live Small Sessions
3. Open Positions
4. Pending Orders
5. Snapshot State
6. Freqtrade Heartbeat
7. Execution Latency
8. Emergency Stop
9. Run Detail Drawer
```

### 前端组件

```text
ExecutionCenterPage
├── ExecutionSummaryCards
├── SessionFilterBar
├── RunSessionTable
├── EmergencyStopButton
├── RunDetailDrawer
│   ├── OverviewTab
│   ├── OrdersTab
│   ├── PositionsTab
│   ├── RuntimeSnapshotTab
│   ├── RiskDecisionTab
│   ├── ReconciliationTab
│   └── LogsTab
```

### 后端接口

```http
GET /api/execution/center
GET /api/execution/runs/{run_id}
POST /api/execution/runs/{run_id}/pause
POST /api/execution/runs/{run_id}/resume
POST /api/execution/runs/{run_id}/stop
POST /api/execution/emergency-stop
```

### 后端改造

ExecutionService 必须输出：

```text
run state
mode
strategy binding
snapshot age
freqtrade heartbeat
risk state
position count
pending order count
reconciliation state
available actions
```

---

## 7.2 订单 / 持仓

### 页面定位

订单 / 持仓页必须以交易所真实状态为核心。

### 核心功能

```text
1. Open Orders
2. Open Positions
3. Filled Orders
4. Cancelled Orders
5. Exchange State
6. Freqtrade State
7. PulseDesk Materialized View
8. State Difference Warning
```

### 后端接口

```http
GET /api/execution/orders
GET /api/execution/positions
GET /api/execution/orders/{order_id}
GET /api/execution/positions/{position_id}
POST /api/execution/positions/{position_id}/force-close
POST /api/execution/orders/{order_id}/cancel
```

### 后端改造

新增：

```text
ExecutionStateAggregator
ExchangeStateFetcher
FreqtradeStateFetcher
PositionMaterializedViewService
```

必须支持：

```text
exchange_order_id
freqtrade_trade_id
pulsedesk_snapshot_id
ordering_confidence
state_difference
```

---

## 7.3 对账总线

### 页面定位

对账总线独立成页。

用于解决：

```text
EmergencyStop
OrderFilled late event
State Lease
Append-only Ledger
Materialized View
Exchange Finality
```

### 核心功能

```text
1. Command Bus Timeline
2. State Lease Monitor
3. Exchange Finality Events
4. Ledger Append Stream
5. Reconciliation Runs
6. Materialized View Result
7. Manual Refresh Exchange State
```

### 后端接口

```http
GET /api/reconciliation/bus
GET /api/reconciliation/runs
GET /api/reconciliation/runs/{run_id}
GET /api/state-leases
GET /api/execution-ledger/events
POST /api/reconciliation/runs/{run_id}/retry
POST /api/reconciliation/refresh-exchange-state
```

### 后端改造

必须实现：

```text
CommandBusService
StateLeaseService
ExecutionLedgerService
ReconciliationService
MaterializedViewService
ExchangeFinalityService
```

---

# 8. RISK

---

## 8.1 风控中心

### 页面定位

风控中心展示账户级和策略级风险。

### 核心功能

```text
1. Account Risk State
2. Daily Loss Guard
3. Weekly Loss Guard
4. Exposure Guard
5. Consecutive Loss Guard
6. Liquidation Guard
7. AI Risk Filter
8. Market Regime Risk
9. Emergency Stop
```

### 后端接口

```http
GET /api/risk/overview
GET /api/risk/account-state
GET /api/risk/guards
POST /api/risk/emergency-stop
POST /api/risk/block-new-entries
POST /api/risk/unblock
```

### 后端改造

RiskService 必须提供：

```text
account risk state
strategy risk state
symbol exposure
loss budget
active locks
risk reason_codes
available risk actions
```

---

## 8.2 止损保护

### 页面定位

止损保护独立成页。

它负责展示：

```text
Structural Stop
Holding Stop Protection
Volatility Lock
Last Known Good Stop
Exchange Protective Stop
```

### 核心功能

```text
1. Position Stop Table
2. Raw Structure Stop
3. Last Known Good Stop
4. Secure Runtime Stop
5. Spread / Depth / Slippage
6. Volatility Lock State
7. Stop Update Allowed
8. Exchange Protective Stop Status
```

### 后端接口

```http
GET /api/risk/stop-protection
GET /api/risk/volatility-locks
GET /api/risk/exchange-protective-stops
POST /api/risk/stop-protection/{position_id}/refresh
POST /api/risk/stop-protection/{position_id}/force-lock
POST /api/risk/stop-protection/{position_id}/release-lock
```

### 后端改造

新增：

```text
StopProtectionService
VolatilityLockService
LastKnownGoodStopStore
ExchangeProtectiveStopService
```

---

## 8.3 熔断记录

### 页面定位

熔断记录展示所有系统级、账户级、策略级熔断事件。

### 核心功能

```text
1. Emergency Stop Records
2. Kill Switch Records
3. Daily Loss Lock Records
4. Weekly Loss Lock Records
5. Manual Force Close Records
6. System Safe Mode Records
7. Related Command ID
8. Related Reconciliation ID
```

### 后端接口

```http
GET /api/risk/circuit-breakers
GET /api/risk/circuit-breakers/{id}
GET /api/risk/emergency-events
```

### 后端改造

RiskService / CommandBusService / LedgerService 需要统一事件格式。

---

# 9. AI RESEARCH

---

## 9.1 AI 投研室

### 页面定位

AI 投研室负责研究，不负责直接交易。

### 核心功能

```text
1. News Analysis
2. Research Summary
3. Whale Behavior Explanation
4. Chain Event Explanation
5. Macro / Regulatory Risk
6. Multi-factor Conflict Analysis
7. AI Risk Cache Preview
```

### 后端接口

```http
GET /api/ai-research/reports
POST /api/ai-research/analyze
GET /api/ai-risk-cache
POST /api/ai-research/generate-cache
```

### 后端改造

AIResearchService 必须只输出：

```text
ai_risk_score
ai_bias
risk_flags
summary
valid_until
evidence
```

禁止输出直接下单命令。

---

## 9.2 Agent 平台

### 页面定位

Agent 平台管理研究和复盘 Agent。

### 核心功能

```text
1. Agent List
2. Agent Task Queue
3. TradingAgents Run
4. AI-Trader Run
5. Review Agent
6. Strategy Improvement Agent
```

### 后端接口

```http
GET /api/agents
GET /api/agents/tasks
POST /api/agents/{agent_id}/run
POST /api/agents/tasks/{task_id}/cancel
```

### 后端改造

新增或重构：

```text
AgentOrchestrator
AgentTaskService
AgentResultStore
```

---

## 9.3 信号中心

### 页面定位

信号中心管理所有信号来源和质量。

### 信号类型

```text
Technical Signal
Structure Signal
AI Signal
News Signal
Whale Signal
On-chain Signal
Risk Signal
```

### 后端接口

```http
GET /api/signals/center
GET /api/signals/sources
GET /api/signals/conflicts
GET /api/signals/{signal_id}
```

### 后端改造

SignalService 需要支持：

```text
signal_source
signal_quality
signal_freshness
signal_conflict
signal_reliability
related_strategy_ids
```

---

## 9.4 市场情绪

### 页面定位

市场情绪展示慢轨情绪和新闻风险。

### 后端接口

```http
GET /api/sentiment/market
GET /api/sentiment/news
GET /api/sentiment/social
GET /api/sentiment/symbol/{symbol}
```

---

# 10. GROWTH

---

## 10.1 复盘成长

### 页面定位

复盘成长是交易结果分析页面。

### 核心功能

```text
1. Trade Review
2. Win / Loss Attribution
3. AI Review Summary
4. Learning Labels
5. Strategy Performance
6. Mistake Timeline
```

### 后端接口

```http
GET /api/growth/review
GET /api/growth/trade-review/{trade_id}
POST /api/growth/trade-review/{trade_id}/generate
```

---

## 10.2 失败聚类

### 页面定位

失败聚类发现策略失败模式。

### 核心功能

```text
1. Failure Label Ranking
2. Market Regime Failure Matrix
3. Structure Failure Matrix
4. Strategy Loss Clusters
5. Common Reject Reasons
6. AI Attribution Cloud
```

### 后端接口

```http
GET /api/growth/failure-summary
GET /api/growth/failure-clusters
GET /api/growth/labels
GET /api/growth/regime-matrix
```

### 后端改造

新增：

```text
FailureClusterService
TradeLabelAnalyticsService
RegimePerformanceAnalyzer
```

---

## 10.3 策略优化

### 页面定位

策略优化生成候选策略，但不能直接上线。

### 安全流程

```text
AI Suggestion
  ↓
Generate Strategy Draft
  ↓
DSL Static Validation
  ↓
Backtest
  ↓
Paper Trade
  ↓
Manual Approval
  ↓
Live Small
```

### 后端接口

```http
GET /api/growth/strategy-suggestions
POST /api/strategies/drafts
POST /api/strategies/validate
POST /api/backtests/run
POST /api/strategies/publish
```

### 后端改造

新增：

```text
StrategySuggestionService
StrategyDraftService
StrategyOptimizationWorkflow
```

---

# 11. SYSTEM

---

## 11.1 服务管理

### 页面定位

服务管理控制本地和后端服务。

### 服务列表

```text
Fast Track Service
Slow Track AI Service
Strategy Orchestrator
Decision Engine
Risk Engine
Structure Engine
Freqtrade Adapter
Redis
PostgreSQL
Worker Queue
```

### 后端接口

```http
GET /api/system/services
GET /api/system/services/{service_id}
POST /api/system/services/{service_id}/restart
POST /api/system/services/{service_id}/stop
GET /api/system/logs
```

---

## 11.2 数据源管理

### 页面定位

数据源管理所有行情、订单簿、新闻、链上数据源。

### 数据源

```text
Exchange Kline
Orderbook
Funding
Open Interest
News
Whale
On-chain
Research Reports
Social Sentiment
```

### 后端接口

```http
GET /api/data-sources
GET /api/data-sources/{source_id}
POST /api/data-sources/{source_id}/test
POST /api/data-sources/{source_id}/enable
POST /api/data-sources/{source_id}/disable
```

---

## 11.3 系统设置

### 页面定位

配置：

```text
账户
交易所 API
AI Provider
默认风控
通知
代理
Docker / Freqtrade
本地路径
安全设置
```

### 后端接口

```http
GET /api/settings
POST /api/settings
GET /api/settings/exchange
POST /api/settings/exchange
GET /api/settings/risk-defaults
POST /api/settings/risk-defaults
```

---

# 12. 统一状态模型

所有页面必须使用统一状态字段。

## 12.1 通用状态

```text
healthy
warning
blocked
locked
running
stopped
failed
reconciling
stale
unknown
```

## 12.2 统一颜色

| 状态 | 颜色 |
|---|---|
| healthy / allow / running | green |
| warning / reduce / dryrun | yellow |
| live_small | orange |
| blocked / failed / emergency | red |
| reconciling / syncing | purple |
| locked / volatility_lock | orange-red |
| stopped / inactive | gray |
| stale / unknown | muted yellow |

## 12.3 所有页面必须展示 reason_codes

示例：

```json
{
  "state": "blocked",
  "reason_codes": [
    "daily_loss_limit_reached",
    "snapshot_stale",
    "freqtrade_heartbeat_lost"
  ]
}
```

---

# 13. 顶部全局状态栏

所有页面顶部必须显示：

```text
System State
Risk State
Fast Track Latency
Freqtrade State
Redis RTT
Exchange State
Open Positions
Emergency Lock
```

示例：

```text
System: LIVE_SMALL_READY
Risk: NORMAL
Fast Track: 45ms
Freqtrade: Healthy
Redis: 3ms
Exchange: OK
Positions: 3
```

危险状态：

```text
System: RISK_LOCKED
Reason: daily_loss_limit_reached
Action: new entries blocked
```

---

# 14. 实施优先级

## P0：实盘安全闭环

```text
OVERVIEW
- Dashboard
- Live Readiness

EXECUTION
- Execution Center
- Reconciliation Bus

RISK
- Risk Center
- Stop Protection
- Circuit Breaker Records

STRUCTURE
- Structure Matrix
```

## P1：策略生产闭环

```text
STRATEGY
- Strategy Workspace
- Strategy Canvas
- Backtest / Simulation

STRUCTURE
- Market Structure
- Manipulation Radar

AI RESEARCH
- AI Research Room
- Signal Center
- Market Sentiment
```

## P2：成长与智能化

```text
AI RESEARCH
- Agent Platform

GROWTH
- Growth Review
- Failure Clustering
- Strategy Optimization
```

## P3：系统管理增强

```text
SYSTEM
- Service Management
- Data Source Management
- Settings
```

---

# 15. 后端重构任务清单

## 15.1 新增 Page ViewModel API

必须新增：

```text
OverviewViewModelService
StrategyViewModelService
StructureViewModelService
ExecutionViewModelService
RiskViewModelService
AIResearchViewModelService
GrowthViewModelService
SystemViewModelService
```

---

## 15.2 新增核心服务

```text
LiveReadinessService
StructureMatrixService
ShadowWindowService
ManipulationRadarService
ReconciliationService
StateLeaseService
StopProtectionService
VolatilityLockService
FailureClusterService
StrategyOptimizationWorkflow
```

---

## 15.3 改造现有服务

```text
StrategyService
CanvasService
ExecutionService
RiskService
AIResearchService
SignalService
SystemService
DataSourceService
```

需要统一输出：

```text
state
reason_codes
available_actions
freshness
latency
source_authority
```

---

# 16. 开发 AI Prompt

```markdown
请按照 PulseDesk 最终产品级信息架构重构前后端。

不要再按旧的 AI QUANT / STRATEGY / EXECUTION / RESEARCH / SYSTEM 分组。
最终导航必须严格采用：

OVERVIEW
- 总览 Dashboard
- 实盘准入 Live Readiness

STRATEGY
- 策略工作台
- 策略画布
- 回测 / 模拟

STRUCTURE
- 市场结构
- 结构矩阵
- 操纵雷达

EXECUTION
- 执行中心
- 订单 / 持仓
- 对账总线

RISK
- 风控中心
- 止损保护
- 熔断记录

AI RESEARCH
- AI 投研室
- Agent 平台
- 信号中心
- 市场情绪

GROWTH
- 复盘成长
- 失败聚类
- 策略优化

SYSTEM
- 服务管理
- 数据源管理
- 系统设置

前端要求：
1. 重构左侧导航。
2. 所有页面必须有明确交易运行问题。
3. 所有页面必须支持 mock data。
4. 所有风险、拒单、锁定、降级必须展示 reason_codes。
5. 所有危险状态必须有颜色和阻断动作。
6. 顶部全局状态栏必须跨页面存在。

后端要求：
1. 新增 Page ViewModel / BFF 聚合层。
2. 不要求后端服务和页面一一对应。
3. 领域服务保持清晰边界，但页面通过聚合 API 获取数据。
4. 所有聚合 API 必须返回 state、reason_codes、available_actions。
5. 新增 LiveReadinessService、StructureMatrixService、ReconciliationService、StopProtectionService、FailureClusterService。
6. Execution 与 Risk 必须以 Exchange/Freqtrade 真实状态为权威。
7. AI Research 只能输出风险解释和缓存，不允许直接下单。
8. Strategy Optimization 只能生成 Draft，必须经过 DSL 校验、Backtest、Paper、Manual Approval 后才能 Live Small。

请输出：
- 路由结构
- 页面组件树
- 后端服务改造
- API 路由
- Mock JSON
- TypeScript 类型
- 数据库变更
- Redis Key 设计
- 状态颜色规范
- 实施优先级
- 验收标准
```

---

# 17. 最终结论

PulseDesk 最终页面架构必须完全按以下交易运行闭环组织：

```text
OVERVIEW → STRATEGY → STRUCTURE → EXECUTION → RISK → AI RESEARCH → GROWTH → SYSTEM
```

这套结构的意义是：

```text
OVERVIEW：看全局
STRATEGY：管策略
STRUCTURE：看市场结构
EXECUTION：看执行事实
RISK：管风险边界
AI RESEARCH：做研究解释
GROWTH：做复盘进化
SYSTEM：管系统服务
```

后端也要从单纯服务接口，升级为：

```text
领域服务 + 页面聚合 API + 统一状态模型 + reason_codes + available_actions
```

最终目标：

> PulseDesk 不再是 AI 功能集合，也不是普通交易 Bot，而是一个真正面向实盘的 AI 结构化自动交易运行控制台。

