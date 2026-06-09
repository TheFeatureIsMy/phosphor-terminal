# Phase 0: 现状审计报告

> 审计日期：2026-06-08
> 审计范围：PulseDesk / Krypton 全部代码库（Backend + macOS App + Canvas-Web + Freqtrade）
> 目的：确认 Signal、Strategy、Canvas、Structure、Execution、Growth 边界，为主流程重构提供差距清单

---

## 1. 项目规模概览

| 层 | 技术栈 | 规模 |
|---|---|---|
| Backend | FastAPI + SQLAlchemy + Redis + PostgreSQL | ~70 服务模块, 34 路由, ~56 张 DB 表, 65+ 测试 |
| macOS App | SwiftUI (macOS 26+), Swift 6.2, SPM | 160+ Swift 文件, 25 页面, 21 ViewModel, 27 API 服务 |
| Canvas-Web | React 19 + React Flow v12 + TypeScript + Vite | 8 节点类型, 0 自定义 Edge, DSL v2.5 双向转换 |
| Freqtrade | Python IStrategy + Redis Snapshot Client | 双模式适配器, 4 状态断连保护, 14 测试 |
| 基础设施 | Docker Compose (postgres/redis/api/freqtrade) | Alembic 3 迁移, 月分区表 |

---

## 2. Signal Center 审查

### 数据模型

- `SignalIdentity` — UUID 锚点
- `Signal` — 分区表 (composite PK: id + created_at)
- `SignalPayload` — 推理/结构化数据
- `SignalEvidence` — 每个 Signal 的证据项
- `SignalLifecycleEvent` — 状态转换记录
- `SignalSnapshot` — 归档前快照

### 状态机

```
pending → active / rejected / expired
active → used_in_strategy / observed_in_paper / rejected / expired
used_in_strategy → executed / archived
```

### API

- `POST/GET /api/v2/signals` — 创建、列表、获取
- 状态转换、归档、publish-to-strategy、observe-paper
- 冲突检测（同 symbol 反方向）、聚合

### 服务

- `SignalService` — 完整 CRUD + 状态机 + publish_to_strategy (Research → SignalCandidate → StrategyDraft)
- `SignalRepository` — 数据访问层

### 前端

- `SignalCenterView` + `SignalCardView` + `SignalDetailSheet`
- `SignalCenterViewModel` — V2 信号列表、筛选、状态转换、归档

### 差距

- ❌ 无 `next_actions` 字段（前后端均无）
- ❌ 无 Signal Funnel View
- ❌ 无 Signal Conflict Panel（后端有冲突检测 API，前端未展示）
- ❌ 无 StrategyDraft Quick Create（后端有 publish_to_strategy，前端未对接）

---

## 3. Strategy Workspace 审查

### 数据模型

- `StrategyV2` — UUID PK, name/type/source/status
- `StrategyVersion` — 版本化 DSL 快照 (dsl_snapshot + dsl_hash)
- `StrategyRuleDSLVersion` — DSL 迁移审计

### 生命周期

策略级：`draft / active / paused / archived / rejected`

版本级（已定义完整链）：
```
draft → validated → backtested → paper_running → paper_passed → live_pending → live_small → paused → archived
```

### DSL

- **v2.5** `RulePackage` — 完整实现 (indicators + entry/exit groups + filters + position_sizing + risk)
- **v3.0** `RulePackageV3` — 后端类型已定义 (StrategyMeta, StopPolicy, AccountRiskPolicy, DisconnectProtection, TimeframeIntegrityPolicy 等)
- 白名单：14 指标, 10 操作符, 8 规则类型

### 差距

- ❌ 无 Strategy Lifecycle Rail UI（后端 VersionStatus 已有完整状态链）
- ❌ 无 MTF Guard Summary Card
- ❌ 无 Shadow Strategy Suggestions Panel
- ❌ Canvas-Web 无 DSL v3.0 转换器（仅 v2.5）
- ❌ Canvas-Web 无 MTF Guard Edge/Node

---

## 4. Canvas DSL 审查

### React Flow 节点类型

| Key | 用途 |
|---|---|
| `signalInput` | 信号输入（单 timeframe） |
| `indicatorCondition` | 指标条件 |
| `filter` | 过滤器 |
| `positionSizing` | 仓位管理 |
| `riskPolicy` | 风控策略 |
| `executionOutput` | 执行输出（5 个输入 handle） |
| `structureDefense` | 结构防御（v3.0，无配置面板） |
| `accountRisk` | 账户风控（v3.0，无配置面板） |

### 差距

- ❌ 无自定义 Edge 类型（全部用默认 smoothstep）
- ❌ 无 MTF Guard Edge（需全新开发：状态连线、Inspector、reason_codes）
- ❌ 无 MTF Guard Node
- ❌ structureDefense 和 accountRisk 节点无配置面板
- ❌ DSL v3.0 无转换器实现
- ❌ dagre 依赖未使用

---

## 5. Structure Matrix / Shadow Window 审查

### 后端 StructureEngine

完整 ICT 市场结构分析引擎（services/structure/），包含：
- Swing 高低点、流动性池、流动性扫荡（含状态机）
- FVG、Order Block、BOS/CHoCH 检测
- 市场状态分类、Entry Score（0-100）、结构生命周期管理

### 跨周期规则

- `timeframe.py` — `can_invalidate_structure(candle_tf, structure_tf)` 仅同级或更高 TF 闭合才能 invalidate
- `lifecycle.py` — `low_tf_violation_count` 跟踪

### 差距

- ❌ StructureMatrixService 返回 mock 数据（需实现真实多 TF 分析）
- ❌ 无 MTF Guard Matrix / Shadow Window 真实状态
- ❌ 无 Temporary Violation Heatmap / Strategy Impact List

---

## 6. Runtime Decision Snapshot 审查

### 已有

- `RuntimeDecisionSnapshot` Pydantic 模型（candidate_signal, indicator/structure/ai/liquidity/risk context, execution_plan）
- Redis Key: `pd:runtime:decision:{strategy_id}:{symbol}:{timeframe}` (TTL 300s)
- `DecisionEngine` 编排：DSL 评估 + Structure 分析 + AI Cache + AccountRiskFirewall + 结构止损

### 差距

- ❌ 无 `mtf_guard_context` 字段
- ❌ DecisionEngine 不聚合多 TF

---

## 7. Execution / Trade 审查

### 已有

- 事件溯源 `ExecutionLedgerEvent` (append-only, 月分区)
- 物化视图：ExecutionOrder, ExecutionTrade, ExecutionPosition, OrderFill
- TradeIntent + RiskDecision 链路
- Freqtrade 双模式 + 4 状态断连保护

### 差距

- ❌ 前端无 Source Trace / RuntimeSnapshot Trace / MTF Guard Trace / FeatureSnapshot Trace

---

## 8. Growth / Failure Cluster 审查

### 已有

- `GrowthService` + trade_analyzer + report_builder + candidate_generator
- `failure_clustering.py` — 按 label 聚类亏损交易
- `trade_reviewer.py` + `label_generator.py`
- `FeatureSnapshot` 表（已定义、已建表、已配置分区）
- 前端 FailureClusteringView + StrategyOptimizationView

### 差距

- ❌ 无 ShadowStrategyDraft / DSLPatchService / ShadowStrategyGeneratorService
- ❌ 无 shadow_strategy_drafts / failure_clusters(DB) / strategy_version_upgrade_requests 表
- ❌ 前端无 Shadow Strategy 操作 UI

---

## 9. MTF / 多周期相关代码

### 已有

- `timeframe.py` + `lifecycle.py` 跨周期 invalidation 规则
- `StructureMatrixService` 多 TF 矩阵（mock）
- `TimeframeIntegrityPolicy` DSL v3.0 类型

### 完全不存在

- MTFTemporalGuardService / 状态机 / DSL 节点 / 数据库表 / Redis 状态 / 回测回放 / React Flow Edge

---

## 10. Shadow Strategy 相关代码

### 已有

- `StrategyRunMode.SHADOW` 枚举（无实现）
- mock shadow-windows BFF 接口

### 完全不存在

- ShadowStrategyDraft 模型 / GeneratorService / DSLPatchService / ValidationService / UpgradeService / DB 表 / API / 前端 UI

---

## 11. 可复用资产清单

| 资产 | 位置 | 可复用于 |
|---|---|---|
| Signal 完整生命周期 + 状态机 | signal_service.py | Phase 1 Signal Funnel |
| StrategyVersion 状态链 | domain/strategy.py | Phase 1 Lifecycle Rail |
| DecisionEngine 编排 | decision_engine.py | Phase 3 MTF Guard 集成 |
| RuntimeDecisionSnapshot | domain/snapshot.py | Phase 3 扩展 |
| RuntimeRedisStore | runtime_redis_store.py | Phase 3 Redis 写入 |
| StructureEngine + 14 子模块 | services/structure/ | Phase 3 真实多 TF |
| timeframe.py + lifecycle.py | services/structure/ | Phase 3 invalidation 规则 |
| LiquiditySweep.SweepState 状态机 | structure/models.py | Phase 3 MTF Guard 状态机参考 |
| FeatureSnapshot 表 | domain/growth.py | Phase 6 |
| trade_reviewer + label_generator | services/ | Phase 6 |
| failure_clustering.py | services/ | Phase 7 |
| candidate_generator.py | services/growth/ | Phase 8 参考 |
| DSL v3.0 类型定义 | domain/dsl.py + canvas-web/types.ts | Phase 3-4 |
| WebView Bridge 协议 | bridge.ts + CanvasBridge.swift | Phase 4 |
| BFF 路由模式 | *_bff.py | Phase 1 Workflow BFF |

---

## 12. 需要新增的数据库表

1. `workflow_states` — Daily Trading Loop 状态
2. `mtf_guard_events` — MTF Guard 事件记录
3. `mtf_guard_backtest_stats` — MTF Guard 回测统计
4. `shadow_strategy_drafts` — 影子策略草稿
5. `failure_clusters` — 失败聚类（持久化版）
6. `strategy_version_upgrade_requests` — 策略升级请求
7. `trade_review_labels` — 交易复盘标签

## 13. 需要新增的后端服务

1. `WorkflowAggregatorService`
2. `MTFTemporalGuardService`
3. `ShadowWindowService`（真实实现）
4. `StructureMatrixService`（真实实现替换 mock）
5. `ShadowStrategyGeneratorService`
6. `DSLPatchService`
7. `ShadowStrategyValidationService`
8. `StrategyUpgradeService`
9. `MTFBacktestReplayService`

## 14. 需要新增的 React Flow 组件

1. `MTFGuardEdge` — 自定义 Edge 类型（7 种状态样式）
2. `MTFGuardNode` — MTF Guard 节点
3. `MTFGuardInspector` — Edge Inspector 面板
4. DSL v3.0 转换器 (dslToGraph / graphToDsl)
5. structureDefense / accountRisk 节点配置面板

## 15. 需要新增的 SwiftUI 组件

1. `TradingWorkflowRailView` — Dashboard Workflow Rail
2. `SignalFunnelView` — Signal Funnel
3. `StrategyLifecycleRailView` — Strategy Lifecycle Rail
4. `MTFGuardSummaryCard` — MTF Guard 摘要
5. `ShadowStrategySuggestionsPanel` — Shadow Strategy 建议面板
6. `TradeSourceTraceView` — 交易来源追踪
7. `ShadowStrategyDraftView` — Shadow Strategy 草稿详情
8. `StrategyUpgradeRequestView` — 策略升级审批

---

## 16. 结论

系统在功能模块层面已相当完整，核心差距集中在三个方面：

1. **流程层缺失** — 功能模块独立存在但未串联为 Daily Trading Loop
2. **MTF 防御层缺失** — 跨周期结构分析框架存在但未产品化为状态机
3. **策略进化层缺失** — 失败聚类和特征归因已有基础但未形成 Shadow Strategy → DSL Patch → 版本升级闭环

好消息是：**大部分底层基础设施已就绪**。重构的核心工作是在这些基础上构建"连接层"和"新能力层"。
