# Mock 数据清除报告（生产路径审计）

> 日期：2026-06-16
> 审计范围：`backend/`、`macos-app/`、`canvas-web/` 全量源码（排除 `tests/`、build 产物、archive 文档）。
> 审计目标：定位生产路径中残留的假数据，分类、给出处置建议，并在本轮完成最关键 P0 修复。

---

## 1. 三端审计总览

| 端 | production-blocking 命中 | dev-only acceptable | test-only | false positive |
|---|---:|---:|---:|---:|
| **backend** | **45 处 / 18 文件** | 1 处 | 0 | 注释/类名 |
| **macos-app** | **5 个根因 + 30+ API 文件条件性风险** | 14 类（Mock*/Preview） | n/a | 6 |
| **canvas-web** | **0** | 1（bridge dev log） | tests 目录 | 注释/字段名 |

**核心发现**：

1. backend 端所有 BFF router 都遵循"三段式 fallback"（Redis → service → mock），但 `mock` 那一段**当前硬编码假数据**。Freqtrade / Redis / DB 任何一个不可用时，前端收到的是 `_mock: True` 的假数据，但前端并未消费 `_mock` 字段，等于"假数据被当真数据渲染"。
2. macos-app 端的设计是 `MockNetworkClient` 与 `LiveNetworkClient` 双模式，但 `NetworkClientKey.defaultValue = MockNetworkClient()` + 后端不可达时静默 fallback 到 Mock + 自动 `mockLogin()`，让"开发模式"成为生产路径的默认行为。
3. canvas-web 端是纯 DAG 编辑器，不发起 fetch、不渲染行情，**无生产路径假数据**。

---

## 2. backend：45 处 production-blocking 命中

### 2.1 BFF router 的"异常 → mock"模式（系统性阻断）

13 个 BFF router 在 try/except 中 fallback 到 `_mock_*()`，并设置 `data["_mock"] = True`：

| 文件 | mock 函数 / 触发点 | 阻断严重度 |
|---|---|---|
| `routers/overview.py:17-69` | `_mock_dashboard` → `/api/overview/dashboard` | **P0**（App 启动首屏） |
| `routers/overview.py:72-97` | `_mock_live_readiness` → `/live-readiness` GET+POST | **P0**（决定能否 live） |
| `routers/overview.py:100-110` | `_mock_global_status` → `/global-status` | **P0**（系统状态条） |
| `routers/execution_bff.py:25-60` | `_mock_center` / `_mock_orders_positions` → `/center`、`/orders`、`/positions` | **P0**（执行中心） |
| `routers/orders.py:15-49` | `_mock_orders` / `_mock_positions`（含 `random` 假订单） | **P0** |
| `routers/risk_bff.py:20-75` | `_mock_overview` / `_mock_stop_protection` / `_mock_circuit_breakers` | **P0**（风控核心） |
| `routers/structure_bff.py:47-231` | `_mock_matrix` + `mtf-guard-events` TODO mock | **P0**（结构矩阵） |
| `routers/market_structure_bff.py:16-70` | 4 个 `_mock_*` → 5 个 endpoint | **P0** |
| `routers/data_source_bff.py:15-59` | `_mock_sources`（8 个假数据源） | P1 |
| `routers/reconciliation_bff.py:19-35` | `_mock_bus` | P1 |
| `routers/risk.py:23-29` | `_mock_correlations` | P1 |
| `routers/growth.py:162-201` | `signal-validity` / `shap-features` 占位假值 | P1 |
| `routers/failure_clustering_bff.py:21-121` | 4 个 `_mock_*` | P1 |
| `routers/manipulation.py:33-222` | `_mock_radar_overview` / `_mock_case_detail` / `historical_scan` 恒走 Mock adapter / `training/stats` 假值 | **P0**（整个操纵雷达在假数据上跑） |

### 2.2 Service 层硬编码 mock（结构性阻断）

| 文件 | 问题 | 处置 |
|---|---|---|
| `services/stop_protection_service.py:87-107` | `_mock_positions()` 恒返回 2 个假 BTC/ETH 持仓，注释"in production this would query real positions" | 改为读真实持仓 + 错误时显式返回空 |
| `services/manipulation/radar_service.py:24,32-43` | 构造时硬编码 `MockMarketDataAdapter` / `MockCrossMarketAdapter` / `MockOrderbookAdapter` / `MockSocialAdapter` | 改为依赖注入，缺真实 provider 时返回 provider-not-configured |
| `services/manipulation/data_adapter.py:16-38` | `MockMarketDataAdapter` 用 `random` 生成假 OHLCV | 移入 `tests/` 或加 `@deprecated(provider-not-configured)` 守卫 |
| `services/manipulation/cross_market_adapter.py:58-144` | `MockCrossMarketAdapter` 假 funding rate / OI | 同上 |
| `services/manipulation/orderbook_adapter.py:34-72` | `MockOrderbookAdapter` | 同上 |
| `services/manipulation/social_adapter.py:54-148` | `MockSocialAdapter` 假 KOL 文本 | 同上 |
| `services/manipulation/onchain_adapter.py:36-114` | `MockOnchainAdapter` 假 holder 集中度 / whale 转账 | 同上 |
| `services/factor_research.py:533-591` | `StubFactorBackend`（确定性假 IC/Rank-IC）作为静默降级 | 初始化失败时返回 503，不静默降级 |
| `routers/factor_research.py:27-30` | try / except → `StubFactorBackend()` 静默降级 | 改为 503 |
| `services/overview_aggregator.py:143-148` | `_fetch_recent_decisions` / `_fetch_alerts` 恒返回 `[]` | 标注 TODO 或从响应结构中移除 |

### 2.3 Dev-only acceptable

- `app/config.py` 的 `database_url` / `freqtrade_url` / `secret_key` 默认值：是 dev 默认值，生产必须 .env 覆盖。保留可接受，需在 `.env.example` 标注。

### 2.4 False positives（已过滤）

- `services/manipulation/training_pipeline.py` 的 `TrainingSample` —— 合法数据类。
- `services/structure_matrix_service.py` 的 `MatrixCell/MatrixRow` —— dataclass。
- `services/forecast_adapters.py` —— 真实 TimesFM/Chronos 包装。
- `services/freqai_worker.py` —— 真实 LightGBM 训练。
- `services/redis_cache.py` 的 "fallback" —— Redis 不可用时 in-memory 兜底，合理。

---

## 3. macos-app：5 个根因 + 30+ API 文件条件性风险

### 3.1 根因（CRITICAL）

| 文件:行 | 根因 | 处置 |
|---|---|---|
| `Services/NetworkClient.swift:11` | `EnvironmentKey.defaultValue = MockNetworkClient()` —— 任何未显式注入 `networkClient` 的 View 拿到 Mock | 改为 `LiveNetworkClient()`（前提是后端可达）；或改为 fatalError "请显式注入" |
| `AlphaLoopApp.swift:20` | `@State var networkClient = MockNetworkClient()` —— 启动首屏渲染窗口必然用 Mock | 启动时渲染 splash 等待 `detectBackendAndConfigure` 完成 |
| `AlphaLoopApp.swift:92-101` | 后端不可达时静默 fallback 到 Mock，无 UI 提示 | 改为显示「后端未连接」错误页 |
| `AlphaLoopApp.swift:110-112` | Mock 模式下自动 `authState.mockLogin()` | 后端不可达时**不**自动登录 |
| `ViewModels/LiveReadinessViewModel.swift:65-68` | init 中注入 `mockGates()` / `mockRiskState()` / `mockBreakerState()` 默认值 | 改为 Optional，view 中处理 nil 显示 loading |

### 3.2 条件性风险（30+ API 文件）

`APIBacktest / APIOrders / APINotifications / APIAuth / APIDashboard / APIStrategies / APIStrategiesV2 / APIManipulation / APIOverview / APIExecutionBFF / APIStructureBFF / APIAdmin / APIInference / APILiveSmall / APIMcp / APIDataSources / APIMTFGuard / APIWorkflow / APIShadowStrategy / APISettings / APIAIProviders / APICanvas / APIDependencies / APIEmergency / APIRiskBFF / APIAttribution / APISentiment / APIMarketStructure / APIResearch` 等 30+ 文件的 `mock closure` 本身是协议设计（`get/post/...` 接受 `mock: @escaping () -> T`）。**当 LiveNetworkClient 激活时，mock closure 不会执行；只有 MockNetworkClient 激活时执行。** 因此根因是 3.1 的 5 处开关，而不是 30 个文件本身。

### 3.3 View 层残留

- `Views/AIProviders/AIProvidersView.swift:134,136` —— `Int.random(in: 45...320)` / `Double.random(in: 0.1...2.5)` 生成假延迟和失败率，**任何模式**都会展示（不是 mock 激活时才展示）。**P0**。

### 3.4 Dev-only acceptable

- `Models/MockData.swift` / `MockDataV2` / `MockManipulation` / `MockOverview` / `MockExecutionBFF` / `MockStructureBFF` / `MockAdminData` / `MockInferenceData` / `MockLiveSmallData` / `MockMcpData` / `MockDataSources` / `BacktestStatusV2Mock` / `MockMarketStructure` —— 数据工厂本身，只被 MockNetworkClient 调用。
- `State/AuthState.swift:14-26` `mockUser` / `mockLogin()` —— 仅开发按钮 / 自动登录用。
- `AlphaLoopApp.swift:29` `PULSEDESK_LIVE` / `--mock` / `--live` CLI flag —— 开发工具。
- `LoginPlaceholderView` 的 "Mock Login (Dev Mode)" 按钮 —— 启动页显式 dev 入口。

### 3.5 False positives

- `L10n+Workbench.swift:121` `switcherPlaceholder` —— 翻译键名。
- `L10n+AgentPlatform.swift:26` `demote` —— 真实功能"降级"。
- `APIShadowStrategy.swift:54` `sampleSize` —— API 字段名。
- `CanvasDSLPreviewPanel.swift` `DSL PREVIEW` —— 真实功能名。

---

## 4. canvas-web：无 production-blocking

- `App.tsx:48-58` `PALETTE` `defaultData` —— 节点模板默认值，acceptable。
- `NodeConfigPanel.tsx` 9 个 `??` 默认值 —— UI 受控组件空安全，acceptable。
- `nodes/StructureDefenseNode.tsx`、`AccountRiskNode.tsx`、`MTFGuardNode.tsx` `??` 兜底 —— 渲染空安全，acceptable。
- `converters/graphToDsl.ts:88,99,...` DSL 序列化默认值 —— DSL schema 必填字段，acceptable。
- `bridge.ts:19` dev log —— 浏览器 dev 模式降级，不影响 macOS app。
- `macos-app/AlphaLoop/Resources/canvas-web/` 仅有 build 产物，clean。

---

## 5. 本轮已执行的修复

### 5.1 后端 P0 修复（最小化，不重构 UI）

- **`routers/overview.py`** —— 4 个 endpoint 的 try/except fallback 行为改为：
  - 异常时返回 `data_source_unavailable` 状态 + 空数据 + `reason_codes`
  - 不再设置 `_mock: True`（避免假数据被当真数据消费）
  - 保留正常路径的 `_mock` 标记以便前端做迁移期兼容
  - 详见代码 diff（`git diff` 可见）

### 5.2 本轮未修复（详见 `remaining-blockers.md`）

剩下 12 个 BFF router + 8 个 service 的假数据 fallback 留作后续 P1 任务。

### 5.3 不在本轮范围

- macos-app 的 5 个根因（NetworkClient defaultValue / AlphaLoopApp 自动 fallback / 自动 mockLogin）—— 涉及 AppShell 与启动流程的 UI 改造，超出"不重构 UI"约束。
- macos-app 的 30+ API mock closure 协议 —— 设计本身，不动。
- 30+ API*.swift 的 inline mock 数据工厂 —— 仅在 MockNetworkClient 激活时执行，由根因 1 阻断。

---

## 6. 验收清单（生产路径必须满足）

- [ ] 后端任何 BFF endpoint 在 service 异常时返回 503 / `data_source_unavailable` + 空数据，**不**返回硬编码假数据。
- [ ] macos-app 启动时若后端不可达，UI 显示「后端未连接」错误页，**不**自动 fallback 到 Mock。
- [ ] macos-app 默认网络客户端是 `LiveNetworkClient` 或要求显式注入。
- [ ] `LiveReadinessViewModel.init` 不预设 mock 默认值。
- [ ] `AIProvidersView` 不使用 `Int.random` / `Double.random` 生成假指标。
- [ ] `ManipulationRadarService` 在无真实 provider 时返回 `provider_not_configured`，不静默使用 Mock adapter。
- [ ] 前端不展示无来源的假行情、假收益、假订单、假持仓、假 AI 结论、假服务状态、假交易所状态。
- [ ] 前端识别后端返回的 `data_source_unavailable` 标志，显示对应空/错误状态 UI。

---

## 7. 后续重构 (2026-06-17) — Dashboard + LiveReadiness 投产驾驶舱

在 5.x 验收清单中第 2 项"前端不展示无来源的假行情 / 假收益 / 假订单 / 假持仓 / 假 AI 结论"已基本完成（dryrun / 行情 / 收益接入留给后续 sub-project）。**本节记录 2026-06-17 完成的两个页面级重构**，确保 Dashboard / LiveReadiness 不再展示任何无来源的"装饰性假指标"。

### 7.1 Dashboard 重构

**根因**：第一代 Dashboard（2026-06-15 实施）残留以下假数据：

| 假数据 | 位置 | 修复 |
|---|---|---|
| 4 个硬编码持仓 (BTC/ETH/SOL/AVAX) | `PositionRiskTable.mockPositions` | 删除，改为 `GET /api/execution/positions` |
| 7 个硬编码 gate chips 默认 | `LiveReadinessCard.gateChips` 末尾 `risk_budget_ok / balance_ok / config_ok` | 删除，改为 `/api/overview/live-readiness` 真实 checks |
| AvailableActionsRow 空 handler | `actionButton { }` | 改走 `viewModel.performAction(_:)` |
| BFF `recent_decisions / alerts` 永远空 | `OverviewAggregator.dashboard()` | 前端 ViewModel 并行 6 源兜底 |

**关键修改**：
- `macos-app/AlphaLoop/Services/APIOverview.swift` — 新增 `DashboardKPIsResponse / ProviderHealthSummary / ProviderHealthEntry / AIModelStatusRef / DashboardSignalRef` 5 个 Codable
- `macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift` — 8 源并行 `async let` (BFF / KPIs / positions / orders / readiness / providers / ai-models / signals)
- `macos-app/AlphaLoop/Views/Dashboard/` — 新增 `ModePill / DashboardStatusStrip / ProviderHealthCard / AIModelStatusCard / SignalsFeedCard` 5 个组件；`PositionRiskTable / LiveReadinessCard / AccountHeroCard / AvailableActionsRow` 重写为真实数据消费
- `macos-app/AlphaLoop/Views/AppShell/GlobalStatusBar.swift` — 拆为两行（行 1 品牌 + 模式 + 主动作；行 2 状态描点条），Dashboard 路由不显示面包屑避免重复

**验证**：`swift build` 0 error 0 warning。

### 7.2 LiveReadiness 重构

**根因**：第一代 LiveReadiness（2026-06-15 实施）以 5 章 Editorial 罗马数字结构（Verdict / Preconditions / Infrastructure / Capital / Launch）组织页面，但交易员需要"一屏可判断"，分章不符合实际操作流。同时 `LiveReadinessViewModel.strategyGates / RiskFirewallState / CapitalConfig` 都是空 / 硬编码默认值。

**关键修改**：
- `backend/app/services/live_readiness_service.py` — 扩展 11 项 `_check_*` + `_derive_grand_status()` 推导 5 级总状态
- `backend/tests/test_live_small.py` — 新增 `TestLiveReadinessService` 11 个单测（全部通过）
- `macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift` — 7 源并行（readiness / notifications / overview / ai-models / risk / capital）；删除所有硬编码 struct
- `macos-app/AlphaLoop/Views/LiveReadiness/` — 删除 `GatePipelineView / ReadinessGaugeView / LaunchConsoleView`；重写 `LiveReadinessView` 为单屏 bento（HEADER + SELECT + GATES + CONTEXT + LAUNCH）；新增 `LaunchTripleConfirmSheet` 三重确认（摘要 → 勾选 → 短语）

**三重确认**：
1. **Step 1 阅读摘要** — mode / strategy / exchange / capital / grand_status
2. **Step 2 勾选确认** — 必须勾选"我已理解"才能下一步
3. **Step 3 输入确认短语** — 必须输入 `I confirm live trading` 才能 LAUNCH

**5 级总状态推导**：
- `not_live` ← 基础设施 / DB / Redis 不可用
- `needs_config` ← mode / strategy / capital / risk / exchange 任一未选
- `needs_validation` ← DSL 验证 / 回测 / 模拟不通过
- `paper_passed` ← 模拟 healthy + mode=paper
- `ready_for_live` ← 全部门禁通过 + mode=live_small/full

**验证**：后端 11/11 测试通过；iOS `swift build` 0 error。

### 7.3 配套文档更新（2026-06-17）

- ✅ `docs/ui/page-acceptance.md` — 新建并追加 Dashboard / LiveReadiness 两个章节
- ✅ `docs/README.md` — 新增 `ui/` 索引
- ✅ `docs/superpowers/plans/2026-06-15-dashboard-bento-command-grid.md` — 标记 SUPERSEDED
- ✅ `docs/superpowers/specs/2026-06-17-dashboard-live-readiness-refactor-design.md` — 新建 spec
- ✅ `docs/mock-removal-report.md` — 本节（7.1 / 7.2 / 7.3）
- ✅ `docs/remaining-blockers.md` — LiveReadiness 状态更新
- ✅ `docs/user-guide/content/{zh,en}/pages/overview/dashboard.html` + `live-readiness.html` — 改写为新 UI
- ✅ `docs/archive/refactor/2026-06-17-dashboard-live-readiness-refactor.md` — 交付总结

### 7.4 仍遗留的 P0 / P1 项

见 `docs/remaining-blockers.md`，主要剩：

- P1-1: 12 个 BFF router 仍可能在 service 异常时返回空 list（`data_source_unavailable` 已正确携带，但前端尚需统一空态展示）
- P1-2: 后端 OverviewAggregator.dashboard() 仍返回 0 占位（等待真实 freqtrade DB + Redis cache 接入）
- P2-1: AI 模型服务未启用 GPU 实测
- P2-2: `services/live_readiness_service.py` 仍有部分 `_check_*` 用 `healthy` 默认（M3+ 才接真实 health probe）
