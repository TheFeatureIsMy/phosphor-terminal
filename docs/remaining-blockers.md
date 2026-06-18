# Remaining Production Blockers

> 最后更新：2026-06-17
> 关联：[mock-removal-report.md](./mock-removal-report.md) · [production-readiness/status.md](./production-readiness/status.md) · [ui/page-acceptance.md](./ui/page-acceptance.md)

本文件列出**未修复的投产阻断项**，按优先级排序。每项含：文件:行、根因、修复策略、预估工时、依赖。

---

## P0 —— 投产前置（8 根因）

### ✅ P0-1~4 · macos-app 启动流程 mock 根因（已修复 2026-06-16）
见上文 ✅ 块。

### ✅ P0-5 · LiveReadinessViewModel 预设 mock 默认值（已修复 2026-06-16）

- **修改**：`macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift`
- **修复**：删除 init 中三行 mock 赋值 + `mockGates()` / `mockRiskState()` / `mockBreakerState()` 三个私有静态方法。View 通过空数组 / 零值 struct 安全处理。
- **验证**：spec review ✅，code quality ✅ Approve。

### ✅ P0-5b · LiveReadinessViewModel 全部硬编码 + LiveReadiness 5 章分页重构（已修复 2026-06-17）

- **修改**：`macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift`（重写为 7 源并行 `async let`）+ `macos-app/AlphaLoop/Views/LiveReadiness/LiveReadinessView.swift`（重写为单屏 bento）+ 删除 `Views/LiveReadiness/{GatePipelineView,ReadinessGaugeView,LaunchConsoleView}.swift`
- **修复**：
  - 删除 `LiveReadinessViewModel.strategyGates / RiskFirewallState / CircuitBreakerState / CapitalConfig` 所有硬编码默认值
  - 7 源并行拉取：`readiness / notifications / overview / ai_models / risk / capital`（不再硬塞 7 个 OK chip）
  - 4 项选择器（mode / strategy / capital / exchange）→ 切换后 `runCheck()` 重算 grand_status
  - 启动必须经过 **三重确认**（摘要 → 勾选 → 输入 `I confirm live trading`）
  - 后端 `live_readiness_service.py` 扩展 11 项 `_check_*` + `_derive_grand_status()` 5 级总状态
- **后端测试**：`backend/tests/test_live_small.py::TestLiveReadinessService` 11 passed
- **iOS 测试**：`swift build` 0 error 0 warning
- **验证**：spec ✅，code review ✅，5 级状态推导 6 个用例全过

### ✅ P0-5c · Dashboard 假数据 + Top bar 重构（已修复 2026-06-17）

- **修改**：`macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift`（重写为 8 源并行）+ `Views/AppShell/GlobalStatusBar.swift`（两行 bar）+ `Views/Dashboard/{AccountHeroCard,LiveReadinessCard,AvailableActionsRow,PositionRiskTable,DashboardStatusBar}.swift`（重写为真实数据消费）+ 新增 `Views/Dashboard/{ModePill,DashboardStatusStrip,ProviderHealthCard,AIModelStatusCard,SignalsFeedCard}.swift`
- **修复**：
  - 删除 `PositionRiskTable.mockPositions`（4 个硬编码 BTC/ETH/SOL/AVAX 持仓）
  - 删除 `LiveReadinessCard.gateChips` 末尾 `risk_budget_ok / balance_ok / config_ok` 默认值
  - 删除 `AvailableActionsRow` 空 handler，改走 `viewModel.performAction(_:)`
  - 顶部 bar 拆为两行：行 1 = 品牌 + 模式胶裹 + 主动作（紧急停止）；行 2 = 状态描点条（providers / exchange / redis / freqtrade / risk / positions / last update）
  - Dashboard 路由隐藏 GlobalStatusBar 面包屑，避免与 `DashboardPageHeader` 重复
  - 真实信号卡片显式展示 `source_agent / source_strategy_id / source_feature_snapshot_id` 三个溯源标签
- **iOS 测试**：`swift build` 0 error 0 warning
- **验证**：spec ✅，code review ✅，13 个卡片全部走真实后端，无占位数值

### ✅ P0-6 · AIProvidersView 假延迟/失败率（已修复 2026-06-16）

- **修改**：`macos-app/AlphaLoop/Views/AIProviders/AIProvidersView.swift` L134, L136
- **修复**：`.random()` → `"—"`（后端 `AIProviderInfo` 暂无 latencyMs / failRatePct 字段）。
- **验证**：spec review ✅，code quality ✅ Approve。

### ✅ P0-7 · stop_protection_service 永真返回假持仓（已修复 2026-06-16）

- **修改**：`backend/app/services/stop_protection_service.py`（重写 159 行）
- **修复**：`get_all()` 改用 `FreqtradeDB.get_open_trades()` + `FreqtradeClient.get_performance()`。错误时返回 `data_source_unavailable` + 空 positions。止损位 `stop_calculation_pending`（StructureEngine.stop_calculator 需要 OHLCV DataFrame，超出 service 上下文）。
- **验证**：spec review ✅，code quality ✅ Approve with minor changes（logger.error → logger.exception 已修）。

### ✅ P0-8 · ManipulationRadarService 硬编码 Mock adapter（已修复 2026-06-16）

- **修改**：`backend/app/services/manipulation/radar_service.py`（重写 112 行）
- **修复**：4 个 adapter 改为构造参数注入。`adapter or MockMarketDataAdapter()` 删除。adapter 缺失时 raise `ProviderNotConfiguredError`。4 个 MockAdapter 类保留作 test fixture（加 `# INTERNAL: test fixture / dev only` 注释）。
- **副作用**：`manipulation.py:80/96/103` 调用 `ManipulationRadarService(db)` 不传 adapter → `scan_symbol` raise 500（**预期行为**，Phase 5 真实数据接入前 adapter 不可用）。
- **验证**：spec review ✅，code quality ✅ Approve with minor changes。

---

- **位置**：`macos-app/AlphaLoop/Services/NetworkClient.swift:11`
- **修复**：`EnvironmentKey.defaultValue = LiveNetworkClient()`。任何未显式注入 `networkClient` 的 View 现在默认拿到 LiveNetworkClient。`--mock` flag 路径保留 MockNetworkClient。
- **验证**：`swift build` 通过，spec review ✅，code quality review ✅（Approve with minor changes 已修）。

### ✅ P0-2 · AlphaLoopApp 启动首屏必走 Mock（已修复 2026-06-16）

- **位置**：`macos-app/AlphaLoop/AlphaLoopApp.swift:20` + `init()` else 分支
- **修复**：`@State` 默认值 + init() 中 else 分支均改为 `LiveNetworkClient()`。`isDetectingBackend` 期间显示 splash。
- **验证**：同 P0-1。

### ✅ P0-3 · 后端不可达时静默 fallback（已修复 2026-06-16）

- **位置**：`macos-app/AlphaLoop/AlphaLoopApp.swift:88-101` + `State/AppState.swift`（新增 `backendUnavailable` / `isDetectingBackend` / `retryBackendTrigger`）+ `Views/Landing/BackendUnavailableView.swift`（新文件）+ `Localization/L10n+System.swift`（新文件，3 个 L10n 键）
- **修复**：不可达时设置 `appState.backendUnavailable = true`，ContentView 显示 `BackendUnavailableView`（图标 + 标题 + 描述 + 重试按钮）。重试通过 `.task(id: appState.retryBackendTrigger)` 重新触发检测。
- **验证**：同 P0-1。`onRetry` 改为 `() async -> Void`，isRetrying 在 Task 中正确重置（code quality fix）。

### ✅ P0-4 · Mock 模式自动 mockLogin（已修复 2026-06-16）

- **位置**：`macos-app/AlphaLoop/AlphaLoopApp.swift:110-112`
- **修复**：删除整个 `if !isLiveMode && !authState.isAuthenticated { authState.mockLogin() }` 块。`--mock` 模式登录由用户手动点 "Mock Login (Dev Mode)" 按钮。
- **验证**：同 P0-1。

### P0-5 · LiveReadinessViewModel 预设 mock 默认值

- **位置**：`macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift:65-67` + L90-108 三个 mock 静态方法
- **根因**：init 中调用 `Self.mockGates()` / `Self.mockRiskState()` / `Self.mockBreakerState()`，即使 LiveNetworkClient + 后端正常，loadData() 完成前短暂展示假值；loadData 失败时永久保留。
- **修复策略**：删除 init 中三行 mock 赋值 + 三个 mock 静态方法。字段保持默认（`[]` / 零值 struct）。View 适配：用 `ForEach(gates)` 空数组安全；`riskBar` 比例计算 `ratio = limit > 0 ? min(used/limit, 1.0) : 0` 对 0 值处理正确。
- **预估工时**：0.3d。

### P0-6 · AIProvidersView 假延迟/失败率

- **位置**：`macos-app/AlphaLoop/Views/AIProviders/AIProvidersView.swift:134,136`
- **根因**：`Int.random(in: 45...320)` / `Double.random(in: 0.1...2.5)` —— 任何模式都展示随机数。
- **修复策略**：替换为 `"—"`。后端 `AIProviderInfo` 没有 `latencyMs` / `failRatePct` 字段（待后端接入），当前显示占位符。
- **预估工时**：0.1d。

### P0-7 · stop_protection_service 永真返回假持仓

- **位置**：`backend/app/services/stop_protection_service.py:87-107`
- **根因**：`_mock_positions()` 恒返回 2 个假 BTC/ETH 持仓。
- **修复策略**：
  - 改为 `FreqtradeDB.get_open_trades()` + `FreqtradeClient.get_performance()` 真实数据
  - 错误时返回 `data_source_unavailable` + 空 positions + `type(e).__name__` reason_code
  - 止损位：StructureEngine.stop_calculator 找到但需要 OHLCV DataFrame（超出 service 上下文），当前标记 `stop_calculation_pending` reason_code
  - 构造注入 FreqtradeClient / FreqtradeDB
- **预估工时**：1d。
- **依赖**：FreqtradeDB / FreqtradeClient 接口确认 ✅（已实施）

### P0-8 · ManipulationRadarService 硬编码 Mock adapter

- **位置**：
  - `backend/app/services/manipulation/radar_service.py:24,32-43`
  - 5 个 adapter 文件（保留作 test fixture，加 `# INTERNAL: test fixture / dev only` 注释）
- **根因**：构造时硬编码 5 个 Mock adapter，scan_symbol() 永远走假数据。
- **修复策略**：
  - 4 个 adapter 改为构造参数注入（`adapter`, `cross_market_adapter`, `orderbook_adapter`, `social_adapter`）
  - `adapter` 不再默认 mock；缺失时 `raise ProviderNotConfiguredError`
  - 4 个 MockAdapter 类保留（test fixture），文件加 dev-only 注释
  - caller `manipulation.py:80/96/103` 当前不传 adapter，调用 `scan_symbol` 会 raise → 500（**这是预期行为**，Phase 5 真实数据接入前 adapter 不可用）
- **预估工时**：0.5d（短期改造）+ Phase 5 真实数据接入（不在本轮范围）。

---

## P1 —— 投产前应修

### ✅ P1-1+3 · 12 个 BFF router 模板化 + factor_research 静默降级（已修复 2026-06-16）

- **修改**：13 个文件（12 router + `services/factor_research.py` StubFactorBackend 标记）
  - `routers/execution_bff.py`, `routers/orders.py`, `routers/risk_bff.py`, `routers/structure_bff.py`（含 `mtf-guard-events` 真实 DB 查询）, `routers/market_structure_bff.py`, `routers/data_source_bff.py`, `routers/reconciliation_bff.py`, `routers/risk.py`, `routers/growth.py`, `routers/failure_clustering_bff.py`, `routers/manipulation.py`, `routers/factor_research.py`, `services/factor_research.py`
- **修复**：删除所有 `_mock_*` 函数 + `data["_mock"] = True` 标记。异常时返回 `data_source_unavailable` + 空数据 + `type(e).__name__` reason_code。同步函数用 `HTTPException 503`。
- **副作用**：`manipulation.py` 的 `/cases` / `/alerts` / `/historical-scan` / `/signals` / `/training/stats` 5 个 endpoint 改 `data_source_unavailable` 结构 + `logger.exception`。
- **验证**：spec review 6/6 ✅，code quality ✅ Approve（critical 修复：Python 3.9/3.11 兼容 `warnings.warn` 替代 `warnings.deprecated` 装饰器）。

### ✅ P1-2 · macos 前端识别 `data_source_unavailable`（已修复 2026-06-16）

- **修改**：
  - **新文件** `Services/BFFResponse.swift` —— `BFFResponse` 协议 + `isDataSourceUnavailable` 计算属性
  - **新文件** `Views/Shared/DataSourceUnavailableView.swift` —— 通用空态 view
  - **修改** `Localization/L10n+System.swift` —— 新增 3 个 L10n 键（zh+en）
  - **修改** `ViewModels/DashboardViewModel.swift` —— 新增 `isDataSourceUnavailable` 字段
  - **修改** `Views/Dashboard/DashboardView.swift` —— `body` 顶部加 `if isDataSourceUnavailable` 分支
- **修复模式**：`BFFResponse` 协议（`state: String` + `reasonCodes: [String]` + `isDataSourceUnavailable: Bool`）→ ViewModel conformance + 字段 → View 顶部 `if` 分支 → `DataSourceUnavailableView` 显示。其他 30+ ViewModel 后续按此模式复制。
- **验证**：spec review 13/13 ✅，code quality ✅ Approve with minor changes（`onRetry` 改 async 已修）。

### ✅ P1-4 · overview_aggregator 空 placeholder 处理（已修复 2026-06-16）

- **修改**：`backend/app/services/overview_aggregator.py`
- **修复**：删除 `_fetch_recent_decisions` / `_fetch_alerts` 两个空方法。`asyncio.gather` 从 6 任务减为 4。返回 dict 中保留 `recent_decisions: []` / `alerts: []` 字面量（前端 `DashboardBFFResponse.CodingKeys` 声明了 `recentDecisions` / `alerts`，移除会 `keyNotFound` 崩溃）。
- **已知限制**：`recentDecisions` / `alerts` 在 live mode 永远为空数组（无功能对应实现）。可在 `DashboardResponse` 加 `features` 位掩码标记 placeholder（未来任务）。
- **验证**：spec review 6/6 ✅，code quality ✅ Approve。

---

## P2 —— 投产前可修可不修

- **P2-1** `services/signal_service.py` placeholder 注释 —— 文档化。
- **P2-2** `services/live_readiness_service.py` placeholder 注释（"healthy" 硬编码）—— 实现真实 health probe。
- **P2-3** `services/redis_cache.py` 命名"fallback" —— 文档化为"in-memory degraded mode"。
- **P2-4** `Workers/handlers.py` placeholder 测试 handler —— 文档化。
- **P2-5** `macos-app/Models/MockData.swift` 等 Mock 工厂 —— 不动（仅供 MockNetworkClient 内部使用），但加 `// INTERNAL: only used by MockNetworkClient` 注释防误用。

---

## 不在本轮范围（已确认合理）

- **canvas-web 节点模板默认值** —— 拖拽新节点的合理默认参数，acceptable。
- **macos-app 30+ API*.swift 的 mock closure 协议** —— 设计本身（`get/post/...` 接受 `mock: @escaping () -> T`），由 P0-1/2/3 阻断后不会执行。
- **macos-app `MockData.swift` / `MockDataV2` 等数据工厂** —— 仅 MockNetworkClient 内部使用。
- **`config.py` 默认值** —— dev 默认值，生产 .env 覆盖；需在 `.env.example` 加注释。
- **canvas-web `bridge.ts:19` dev log** —— 浏览器 dev 模式降级，不影响 macOS app。
- **`services/forecast_adapters.py`** —— 真实 TimesFM/Chronos 包装。
- **`services/freqai_worker.py`** —— 真实 LightGBM 训练。

---

## 总工时估算

| 阶段 | 工时 | 累计 |
|---|---:|---:|
| P0 全清 | ~4.0d | 4.0d |
| P1-1（12 router 修复模板化） | ~3.5d | 7.5d |
| P1-2（前端识别 data_source_unavailable） | ~2.0d | 9.5d |
| P1-3 / P1-4 | ~0.5d | 10.0d |
| P2 | ~0.5d | 10.5d |

**投产门槛**：P0 全清后 → 可进入小资金 dry-run 验证。P1 全清后 → 可进入 live_small 试运行。
