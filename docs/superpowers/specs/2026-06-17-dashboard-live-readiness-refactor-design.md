---
title: Dashboard + LiveReadiness — Production Cockpit Refactor (2026-06-17)
status: implemented
date: 2026-06-17
authors: claude
supersedes:
  - docs/superpowers/specs/2026-06-15-dashboard-bento-command-grid-design.md (for data authenticity + top bar)
  - docs/superpowers/specs/2026-06-15-live-readiness-industrial-control-design.md (for single-screen layout)
related:
  - docs/ui/page-acceptance.md
  - docs/archive/refactor/2026-06-17-dashboard-live-readiness-refactor.md
  - docs/product/ia_backend_redesign.md (§4.2 Live Readiness, §4.1 Overview)
---

# Dashboard + LiveReadiness — Production Cockpit Refactor

## Why this refactor

The 2026-06-15 规划交付的 Dashboard / LiveReadiness 已基本搭建，但仍然存在三类问题，达不到"投产状态驾驶舱"标准：

1. **假数据** — `PositionRiskTable.mockPositions` 写死 4 个 BTC/ETH/SOL/AVAX 持仓；`LiveReadinessCard.gateChips` 末尾硬塞 `risk_budget_ok / balance_ok / config_ok` 默认值；`AvailableActionsRow` 按钮 handler 是空 closure；BFF `recent_decisions` / `alerts` 永远返回空数组。
2. **顶部栏简陋** — `GlobalStatusBar` 只显示面包屑 + 语言/主题/搜索/通知，缺模式/provider 健康/紧急动作入口。
3. **LiveReadiness 章节化** — 旧版拆为 5 章 Editorial 罗马数字结构（Verdict / Preconditions / Infrastructure / Capital / Launch），但用户是交易员，需要一屏可判断。

## 目标

- Dashboard 重构：所有卡片 100% 真实 API，模式 + provider 健康 + 紧急控制提到顶部 bar，重复标题合并为单一 page header。
- LiveReadiness 重构：单屏 bento，5 级总状态 + 11 项门禁（按 group 分两列）+ 4 项选择器（mode/策略/资金/交易所）+ 上下文摘要 + 启动授权；启动必须经过三重确认（摘要 → 勾选 → 短语）。

## 范围

### 1. 数据层

- `backend/app/services/live_readiness_service.py` — 扩展 11 个 `_check_*` + `_derive_grand_status()` 推导 5 级总状态
- `backend/app/schemas/overview.py` — `LiveReadinessResponse` 加 `grand_status / selected_* / available_*` 字段；`ReadinessCheck` 加 `detail / group` 字段
- `backend/app/routers/overview.py` — `/live-readiness` 接受 query 参数（GET）/ JSON body（POST），返回 options list
- `backend/tests/test_live_small.py` — 新增 11 个 `TestLiveReadinessService` 单测（11 passed）
- `macos-app/AlphaLoop/Services/APIOverview.swift` — 扩展 Codable；`APIOverview` 加 `getKPIs / getProviderHealth / getAIModelStatus / getRecentSignals`
- `macos-app/AlphaLoop/Services/APIDashboard.swift` — 删 `getRiskEvents / getCorrelation` 残留
- `macos-app/AlphaLoop/Services/APIExecutionBFF.swift` — 已存在的 `PositionBFFResponse.stateDifference` 字段被消费
- `macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift` — 8 源并行 `async let`
- `macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift` — 7 源并行；删 `strategyGates / RiskFirewallState / CircuitBreakerState / CapitalConfig` 硬编码

### 2. 视图层

- Dashboard 视图：保留 `DashboardView` bento 框架；删 `LiveReadinessCard.gateChips` 默认；改 `AccountHeroCard` 双源（BFF + KPIs）；`LiveReadinessCard` 渲染真实 checks；`AvailableActionsRow` 接 `performAction`；`PositionRiskTable` 删 mockPositions + 加 `stateDifference` 列。
- 新增 Dashboard 组件：`ModePill / DashboardStatusStrip / ProviderHealthCard / AIModelStatusCard / SignalsFeedCard`。
- 顶部栏：`GlobalStatusBar` 改为两行（行 1 = 品牌 + 模式胶裹 + 主动作；行 2 = 状态描点条）；Dashboard 路由下隐藏面包屑避免重复。
- LiveReadiness 视图：删 `GatePipelineView / ReadinessGaugeView / LaunchConsoleView` 3 个旧文件；重写 `LiveReadinessView` 为单屏 bento：HEADER（5 级徽章）→ SELECT（4 选择器）→ GATES（11 项两列）→ CONTEXT（6 chip + 2 gauge + 紧急停止）→ LAUNCH（3 按钮 + 阻断项）；新增 `LaunchTripleConfirmSheet` 三重确认。

### 3. i18n

- `Localization/L10n+Dashboard.swift` — 新增 40+ key
- `Localization/L10n+LiveReadiness.swift` — 新增 50+ key（含 5 级状态、11 项指标、3 重确认、group 标签）

### 4. 文档

- `docs/ui/page-acceptance.md` — 新建并追加 Dashboard / LiveReadiness 两个章节
- `docs/README.md` — 新增 `ui/` 索引
- `docs/superpowers/plans/2026-06-15-dashboard-bento-command-grid.md` — 标记 SUPERSEDED
- `docs/mock-removal-report.md` — 追加「后续重构 (2026-06-17)」
- `docs/remaining-blockers.md` — 更新 LiveReadiness 相关状态
- `docs/user-guide/content/{zh,en}/pages/overview/dashboard.html` + `live-readiness.html` — 改写为新 UI
- `docs/archive/refactor/2026-06-17-dashboard-live-readiness-refactor.md` — 新建交付总结

## 不在范围

- 后端 BFF 聚合器（`OverviewAggregator`）的"双源合并"工作（应在 sub-project 8 处理）
- 真实 notification 配置 UI（Telegram bot setup）
- 真实 emergency stop endpoint（仍用 `APIEmergency` 占位）
- 真实 launch endpoint（`/api/v2/live-small/launch` 待后端实现）

## 验收

- ✅ Backend: 11/11 `TestLiveReadinessService` 单测通过
- ✅ iOS: `swift build` 0 error 0 warning
- ✅ 11 项门禁 + 5 级总状态推导（6 个状态梯子用例全部通过）
- ✅ 4 个选择器切换实时回传给后端并重算 grand_status
- ✅ 三重确认：摘要 → 勾选 → 短语 → API 真实调用
- ✅ 5 级颜色映射：绿(ready) / 青(paper) / 琥珀(needs_validation) / 黄(needs_config) / 红(not_live)
- ✅ 顶部 bar 两行；Dashboard 路由不显示重复面包屑
- ✅ 文档：8 处全部同步（README / page-acceptance / 旧 plan / 新 spec / mock-removal / remaining-blockers / 用户指南 / archive）

详细见 [`docs/archive/refactor/2026-06-17-dashboard-live-readiness-refactor.md`](../../archive/refactor/2026-06-17-dashboard-live-readiness-refactor.md)。
