# Page Acceptance — Dashboard (总览 / Cockpit)

> Production-grade acceptance checklist for the `/总览` (Dashboard) page.
> Every metric on the page must be sourced from the live backend. When the
> source is unavailable, an explicit `DATA SOURCE UNAVAILABLE` tag replaces
> the value — no fabricated numbers.

**Last updated:** 2026-06-17
**Status:** ✅ Built (swift build passes)
**Owner:** Trading App Team
**Related plan:** `.claude/plans/enumerated-crafting-frost.md`

---

## §1 目标 / 范围

| 维度 | 目标 |
|---|---|
| 数据真实性 | 100% 真实 API，无占位数值 |
| 模式可见性 | 顶部 bar 显式显示 LIVE / PAPER / DRYRUN / STOPPED / MOCK |
| Provider 健康 | 顶部状态条 + 卡片级 provider 摘要 |
| 信号溯源 | 每个信号展示 `source_agent` / `source_strategy_id` / `source_feature_snapshot_id` |
| 紧急控制 | 顶部 bar 紧急停止按钮可一键触发 |
| 视觉 | 液态玻璃 bento 网格（iOS 26 glassEffect / GlassEffectContainer） |
| i18n | 全卡片中英双语，切换语言无残留 |

---

## §2 数据真实性验收清单

### 2.1 卡片 ↔ 真实端点

| 卡片 | 数据源（端点） | 空态文案 | 失败行为 |
|---|---|---|---|
| `AccountHeroCard` | `GET /api/overview/dashboard` → `account` + `GET /api/dashboard/kpis` | `—` + `DATA SOURCE UNAVAILABLE` 徽章 | 不可达时回退到 KPI；双源均为 0 时显示空态 |
| `DashboardStatusBar` | `GET /api/overview/dashboard` → `system` | `—` | 字段缺失时显示破折号 |
| `StrategyRuntimeCard` | BFF `runtime` | `—` | 0 策略时显示 0，不显示历史 |
| `LiveReadinessCard` | `GET /api/overview/live-readiness` → `checks` + BFF `system` | `暂无 readiness 数据` | 不再硬塞 7 个 OK chip |
| `GlobalRiskCard` | BFF `risk` | `—` | 字段缺失时显示破折号 |
| `PositionRiskTable` | `GET /api/execution/positions` | `无持仓` / `DATA SOURCE UNAVAILABLE` | **已删除 mockPositions**，全部来自 freqtrade |
| `ProviderHealthCard` | `GET /api/admin/providers/categories` | `未配置 provider` | total=0 时显示空态 |
| `AIModelStatusCard` | `GET /api/ai/models/runtime` | `未拉取 AI 模型状态` | models=[] 时显示空态 |
| `SignalsFeedCard` | `GET /api/agent-signals/signals` | `暂无最新信号` | 无信号时显示空态 |
| `RecentDecisionFeed` | BFF `recent_decisions` | `暂无决策` | 空数组显示空态 |
| `AlertTimeline` | BFF `alerts` | `暂无告警` | 空数组显示空态 |
| `EmergencyActionBar` | `POST /api/v2/emergency/stop` | — | 调用后由 `APIEmergency` 真实下发 |

### 2.2 假数据清除

- ✅ **删除** `PositionRiskTable.mockPositions`（BTC/ETH/SOL/AVAX 4 个硬编码持仓）
- ✅ **删除** `LiveReadinessCard.gateChips` 末尾 `["risk_budget_ok", "balance_ok", "config_ok"]` 硬编码默认
- ✅ **删除** `AvailableActionsRow` 按钮的空 handler；改走 `viewModel.performAction(_:)`
- ✅ **删除** `APIDashboard.getRiskEvents/getCorrelation` 调用方残留（仅保留真正使用方）
- ✅ **删除** Dashboard 内裸英文/裸中文硬编码字符串（全部走 `L10n.Dashboard.*`）

### 2.3 失败回退

- 后端 BFF `state == "data_source_unavailable"` → `DashboardViewModel.isDataSourceUnavailable = true` → 渲染 `DataSourceUnavailableView`
- 单卡片依赖的子端点失败 → 该卡片渲染空态 + 标签，其它卡片不受影响
- 紧急停止失败 → `ErrorHandler.handle` 显示 toast，按钮恢复可点

---

## §3 Top Bar 验收清单

### 3.1 行 1 — 品牌 + 模式 + 主动作

- [ ] 左侧：非 Dashboard 路由显示面包屑 `// ROUTE`；Dashboard 路由下显示品牌 `弈机 AlphaLoop`
- [ ] 中部：`ModePill` 显示当前模式（LIVE / PAPER / DRYRUN / STOPPED / MOCK / NOT READY）
- [ ] 模式颜色映射正确：LIVE=accent / PAPER=cyan / DRYRUN=purple / STOPPED=danger / MOCK=warning
- [ ] 右侧动作：语言切换 / 主题切换 / 命令面板 (⌘K) / 通知 (含未读红点) / 紧急停止
- [ ] 紧急停止点击 → 弹 `confirmDialog` → 二次确认 → 真实调用 `APIEmergency.emergencyStop` → toast 反馈

### 3.2 行 2 — 状态描点条

- [ ] 7 个状态 chip：PROVIDERS / EXCHANGE / REDIS / FREQTRADE / RISK / POSITIONS / LAST UPDATE
- [ ] 每个 chip 颜色：绿=正常 / 橙=警告 / 红=异常 / 灰=未知
- [ ] PROVIDERS chip 显示 `healthy/total`（例 `7/9`）
- [ ] REDIS chip 显示 `RTT ms`
- [ ] FREQTRADE chip 显示 `HEALTHY/RUNNING/...`
- [ ] RISK chip 显示 `NORMAL/WARNING/...` + `LOCKED` 标识
- [ ] POSITIONS chip 显示当前持仓数
- [ ] LAST UPDATE 实时刷新（每 15s）

### 3.3 重复标题修复

- [ ] Dashboard 路由下，GlobalStatusBar 行 1 不再显示 `// 总览` 面包屑（改用 `// 弈机 AlphaLoop`）
- [ ] Dashboard 内部 `DashboardPageHeader` 显示 `// 驾驶舱 COCKPIT` + ModePill
- [ ] 任何路径下不会同时出现 `// 总览` 和 `// 驾驶舱`

---

## §4 视觉验收清单

### 4.1 卡片基座

- [ ] 所有卡片使用 `KryptonCard(emphasis:)`（subtle / balanced / bold）
- [ ] `bold` 仅用于 AccountHero（带 3D 倾斜 + spotlight 跟随光标）
- [ ] `subtle` 用于：StatusBar / Positions / Provider / AI / Signals / Decisions / Alerts
- [ ] `balanced` 用于：Runtime / Readiness / Risk

### 4.2 玻璃质感

- [ ] 每张卡片有 `bg-[colors.cardBackground]` + `PulseColors.border` 1px 描边
- [ ] 卡片圆角统一 `PulseRadii.card`（≈ 8px）
- [ ] 阴影使用 `PulseShadow.card(colors)`（低饱和、轻微抬升）
- [ ] 顶部高光横线（来自 `KryptonCard.topHighlightLine`）
- [ ] 重点卡片用 `PulseColors.accent` / `PulseColors.danger` opacity 渐变

### 4.3 状态点 / 描点条

- [ ] 状态点直径 5-6px，带 `shadow(color: opacity 0.4, radius: 2)` glow
- [ ] 描述文字 `PulseFonts.micro` + `textCase(.uppercase)` + `tracking 0.4-0.5`
- [ ] 数字 `PulseFonts.monoLabel` + `monospacedDigit`

### 4.4 数值格式

- [ ] 金额：千分位（$10,248.32）
- [ ] 百分比：`%+.2f%%`（带正负号）
- [ ] 价格：`< 1` 显示 4 位小数 / `>= 1` 显示 2 位 / `>= 1000` 显示整数
- [ ] PnL：正数绿（accent），负数红（danger）

### 4.5 间距

- [ ] 卡片间距 `PulseSpacing.sm` (10pt) 横向
- [ ] 卡片内边距 `PulseSpacing.md` (16pt)
- [ ] 状态点直径 5-6px
- [ ] 行 1 高度 40pt / 行 2 高度 24pt

---

## §5 i18n 验收清单

### 5.1 新增 key（在 `L10n+Dashboard.swift`）

| Key | 中文 | English |
|---|---|---|
| `pageHeader` | 驾驶舱 | Cockpit |
| `pageSubtitle` | 实时驾驶舱 · 所有指标均为后端真实数据 | Real-time cockpit · Every metric is sourced from the live backend |
| `dataSourceBadge` | LIVE | LIVE |
| `dataSourceUnavailable` | 数据源暂不可用 | DATA SOURCE UNAVAILABLE |
| `modeTitle` | 运行模式 | MODE |
| `modeLive` | 实盘 LIVE | LIVE |
| `modePaper` | 模拟 PAPER | PAPER |
| `modeDryRun` | 演练 DRYRUN | DRYRUN |
| `modeStopped` | 已停止 STOPPED | STOPPED |
| `modeMock` | MOCK | MOCK |
| `modeNotReady` | 未就绪 | NOT READY |
| `providers` | PROVIDER | PROVIDERS |
| `aiModels` | AI 模型 | AI MODELS |
| `lastUpdate` | 最近更新 | LAST UPDATE |
| `totalPnl` | 累计盈亏 | TOTAL P&L |
| `winRate` | 胜率 | WIN RATE |
| `todaysTrades` | 今日交易 | TODAY'S TRADES |
| `mark` | 现价 | MARK |
| `liveReadinessChecks` | 准入检查项 | READINESS CHECKS |
| `readinessNoData` | 暂无 readiness 数据 | No readiness data available |
| `actionStartPaper` | 启动模拟 | START PAPER |
| `actionStartLiveSmall` | 启动小仓实盘 | START LIVE SMALL |
| `actionStartFullLive` | 启动全量实盘 | START FULL LIVE |
| `actionCancelAll` | 取消全部挂单 | CANCEL ALL ORDERS |
| `actionForceClose` | 强制平仓 | FORCE CLOSE |
| `actionRunCheck` | 运行就绪检查 | RUN READINESS CHECK |
| `actionRefresh` | 刷新 | REFRESH |
| `stateInSync` | 本端/交易所同步 | IN SYNC |
| `stateDrift` | 存在差异 | DRIFT |
| `stateLocalOnly` | 仅本端 | LOCAL ONLY |
| `stateExchangeOnly` | 仅交易所 | EXCHANGE ONLY |
| `stateUnknown` | 状态未知 | STATE UNKNOWN |
| `providerHealth` | PROVIDER 健康 | PROVIDER HEALTH |
| `providerSummary(_:_:_:_:)` | 共 N 个 · 正常 N · 警告 N · 异常 N | N total · N healthy · N warn · N error |
| `providerStatusOk` | 正常 | OK |
| `providerStatusWarn` | 警告 | WARN |
| `providerStatusError` | 异常 | ERROR |
| `providerNoData` | 未配置 provider | No providers configured |
| `providerCategory(_:)` | 分类 | category name |
| `aiModelStatus` | AI 模型 | AI MODELS |
| `aiModelsLoaded` | 已加载 | LOADED |
| `aiModelsMissing` | 未配置 | MISSING |
| `aiModelsNoData` | 未拉取 AI 模型状态 | No AI model status available |
| `signalsFeed` | 最新信号 (含溯源) | SIGNAL FEED (WITH SOURCE) |
| `signalSourceAgent` | 来源 Agent | AGENT |
| `signalSourceStrategy` | 关联策略 | STRATEGY |
| `signalSourceSnapshot` | 特征快照 | SNAPSHOT |
| `sourceNotTraced` | 未关联溯源 | NO TRACE |
| `noSignals` | 暂无最新信号 | No recent signals |
| `noAlerts` | 暂无告警 | No alerts |
| `collapsePanel` | 收起面板 | COLLAPSE |
| `expandPanel` | 展开面板 | EXPAND |

### 5.2 切换语言验收

- [ ] 所有可见字符串在 `L10n.zh(_:en:)` 或 `L10n.Dashboard.*` 中
- [ ] 切换语言后 < 100ms 内刷新（`@Environment(SettingsState.self)` + `id(settingsState.language)`）
- [ ] 无残留英文 / 中文裸字符串（除技术 token：LIVE / DRYRUN / API 字段名）
- [ ] `grep -rE '"[A-Za-z]' macos-app/AlphaLoop/Views/Dashboard` 不出现非 mock / symbol 英文硬编码

---

## §6 性能 / 行为验收

| 项 | 期望 | 实测 |
|---|---|---|
| 初次加载 | 全部 8 个并行源在 3s 内完成 | — |
| 30s 轮询 | 不阻塞 UI，无内存泄漏 | — |
| 紧急停止响应 | < 1s 二次确认 → 真实 POST → toast | — |
| 后端不可达 | Dashboard 显示 `DataSourceUnavailableView`，可重试 | — |
| 切换 mock/live 模式 | `--mock` 模式胶裹显示 `MOCK`；卡片显示空态 | — |
| Top bar 状态条轮询 | 15s 间隔，毫秒级更新 | — |

---

## §7 关键文件路径

| 类型 | 路径 |
|---|---|
| 数据层 | `macos-app/AlphaLoop/Services/APIOverview.swift`, `macos-app/AlphaLoop/Services/APIDashboard.swift` |
| ViewModel | `macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift` |
| 主视图 | `macos-app/AlphaLoop/Views/Dashboard/DashboardView.swift` |
| 子视图 | `macos-app/AlphaLoop/Views/Dashboard/{AccountHero,LiveReadiness,GlobalRisk,StrategyRuntime,PositionRisk,RecentDecision,Alert,EmergencyAction,AvailableActions,DashboardStatusBar}.swift` |
| 新组件 | `macos-app/AlphaLoop/Views/Dashboard/{ModePill,DashboardStatusStrip,ProviderHealthCard,AIModelStatusCard,SignalsFeedCard}.swift` |
| 顶栏 | `macos-app/AlphaLoop/Views/AppShell/GlobalStatusBar.swift` |
| i18n | `macos-app/AlphaLoop/Localization/L10n+Dashboard.swift` |
| 设计系统 | `macos-app/AlphaLoop/Views/Shared/AlphaLoopComponents.swift` (KryptonCard) |

---

## §8 验证命令

```bash
# 1. iOS 编译
cd macos-app && swift build           # 必须 0 error

# 2. 后端 BFF 形状
curl -s localhost:8000/api/overview/dashboard | jq
curl -s localhost:8000/api/dashboard/kpis | jq
curl -s localhost:8000/api/execution/positions | jq
curl -s localhost:8000/api/overview/live-readiness | jq
curl -s localhost:8000/api/admin/providers/categories | jq
curl -s localhost:8000/api/ai/models/runtime | jq
curl -s localhost:8000/api/agent-signals/signals | jq

# 3. i18n 体检
grep -rE '"[A-Za-z]' macos-app/AlphaLoop/Views/Dashboard | grep -v mock | grep -v L10n

# 4. 真机 / 模拟器运行
cd macos-app && swift run -- --mock   # mock 模式：所有卡片显示 DATA SOURCE UNAVAILABLE
cd macos-app && swift run             # live 模式：所有卡片显示真实数据

# 5. 紧急停止 e2e
#    顶部 bar 点击 "EMERGENCY STOP" → 二次确认 → 调用 /api/v2/emergency/stop → toast
```

---

# Page Acceptance — Live Readiness (实盘准入 / 一屏可判断)

> Single-screen, dense "judgment-at-a-glance" control panel. Core verdict on
> 11 gates + 5-level grand status; no pagination; triple confirmation required
> for live launch.

**Last updated:** 2026-06-17
**Status:** ✅ Built (swift build passes, 11/11 backend tests pass)
**Owner:** Trading App Team

---

## §1 目标 / 范围

| 维度 | 目标 |
|---|---|
| 一屏可判断 | 5 级总状态徽章 + 11 项门禁 + 选 mode/策略/资金/交易所 4 项选择器，**全部首屏可见** |
| 真实数据 | 删除所有 `strategyGates` 硬编码 / 假 `RiskFirewallState` / 默认 `CapitalConfig`；全部走 `/api/overview/live-readiness` + 并行 6 源 |
| 防误触 | 启动必须经过三重确认（启动摘要 → 勾选理解 → 输入确认短语） |
| 视觉 | 与 Dashboard 看齐：液态玻璃 `KryptonCard` + iOS 26 GlassEffect |
| 模式感知 | Mode 切换立刻触发 `/api/overview/live-readiness` 重算 grand_status |

## §2 5 级总状态

| 状态 | 触发条件 | UI 表现 |
|---|---|---|
| `not_live` | 基础设施 / 数据源 / DB 不可用 | 红色徽章 + 阻断项列表 |
| `needs_config` | mode / strategy / capital / risk_config / exchange 任一未选 | 黄色徽章 + 4 个选择器全部未选 |
| `needs_validation` | DSL 验证 / 回测 / 模拟未通过 | 琥珀色徽章 + 阻断项列表 |
| `paper_passed` | 模拟通过 (dryrun healthy) | 青色徽章 + "可启动模拟"按钮 |
| `ready_for_live` | 全部门禁通过 (mode = live_small/full) | 绿色徽章 + "可启动小仓实盘" |

后端推导逻辑：`/Users/novspace/workspace/phosphor-terminal/backend/app/services/live_readiness_service.py:140-180` (`_derive_grand_status`)
后端测试：`backend/tests/test_live_small.py::TestLiveReadinessService` (11 passed)

## §3 11 项门禁

| Key | Group | 来源 |
|---|---|---|
| `mode` | mode | `selected_mode` 入参 |
| `strategy` | strategy | `selected_strategy_id` 入参 |
| `capital` | capital | `selected_capital_pool_id` 入参 |
| `risk_config` | risk | 服务端 policy |
| `exchange` | system | `selected_exchange` 入参 |
| `data_source` | system | 服务端 health check |
| `validation` | strategy | DSL 验证 |
| `backtest` | execution | 至少 1 条回测 |
| `dryrun` | execution | 模拟 ≥ 72h |
| `notification` | system | 通知配置 |
| `emergency_stop` | system | APIEmergency 可用 |

视觉：每个 chip 显示 `dot + label + value`，dot 颜色：绿=OK / 橙=WARN / 红=FAIL / 灰=未知。
按 group 分两列：左 `mode/strategy/capital/risk`，右 `system/execution`。

## §4 4 项选择器

| 字段 | 数据源 | 切换后行为 |
|---|---|---|
| 模式 (mode) | `data.selected_mode` | 立即 `setMode(_:)` → `runCheck()` 重新算 grand_status |
| 策略 (strategy) | `/api/strategies` | `setStrategy(_:)` → `runCheck()` |
| 资金池 (capital) | `/api/live-small/evaluate` 关联 CapitalPool | `setCapitalPool(_:)` → `runCheck()` |
| 交易所 (exchange) | `/api/admin/providers` CEX | `setExchange(_:)` → `runCheck()` |

任何空选择器：显示「未选择」+ 状态 `needs_config`。

## §5 三重启动确认（防误触）

启动按钮 → sheet 弹出 → 3 步走：

1. **Step 1: 阅读启动摘要** — 显示 mode / strategy / exchange / capital / grand_status
2. **Step 2: 勾选确认** — 必须勾选 "我已理解" 才能进入下一步
3. **Step 3: 输入确认短语** — 必须输入 `I confirm live trading` 才能点 LAUNCH
4. **LAUNCH** — 真实调用 `APIEmergency.emergencyStop` + 重新 `loadData()`

文案 key：`L10n.LiveReadiness.confirmTitle / confirmStep1 / confirmStep2 / confirmStep3 / confirmPhrase`。

## §6 上下文摘要

6 chip 网格 + 2 风险 gauge + 1 紧急停止 chip：

| Chip | 真实端点 |
|---|---|
| NOTIFICATIONS | `/api/notifications` |
| AI MODELS | `/api/ai/models/runtime` |
| DATA SOURCE | `/api/overview/global-status` |
| EXCHANGE | `/api/overview/global-status` |
| FREQTRADE | `/api/overview/global-status` |
| REDIS | `/api/overview/global-status` |
| DAILY USED | `/api/risk/overview` guards |
| WEEKLY USED | `/api/risk/overview` guards |
| EMERGENCY STOP | `/api/risk/overview` emergencyLocked |

## §7 删除的旧实现

- ✅ 删除 `Views/LiveReadiness/GatePipelineView.swift`（用 ViewModel.strategyGates，已空）
- ✅ 删除 `Views/LiveReadiness/ReadinessGaugeView.swift`（单一 score 大环，不再需要）
- ✅ 删除 `Views/LiveReadiness/LaunchConsoleView.swift`（旧启动按钮）
- ✅ 删除 `ViewModel.strategyGates / RiskFirewallState / CircuitBreakerState / CapitalConfig` 硬编码默认值
- ✅ 删除 5 章 Editorial 罗马数字结构（chapter I-V）

## §8 验收清单

### 8.1 数据真实性
- [ ] 11 项门禁全部从 `/api/overview/live-readiness?mode=...&strategy_id=...` 真实获取
- [ ] 选择器下拉项从 `data.availableStrategies/CapitalPools/Exchanges` 读取
- [ ] 上下文 chip 全部从并行 6 源真实数据
- [ ] 没有任何硬编码假数据

### 8.2 一屏可判断
- [ ] 不滚动即可看到：5 级总状态徽章 + 4 个选择器 + 11 项门禁 + 上下文 + 启动按钮
- [ ] 单 ScrollView，无 chapter 段落，无分页，无 stepper 分步
- [ ] grand_status 颜色 + 描述 + 阻断项列表同时呈现

### 8.3 三重确认
- [ ] 启动按钮 disabled 当 grand_status ≠ paper_passed/ready_for_live
- [ ] sheet 3 步：摘要 → 勾选 → 输入短语
- [ ] 短语不匹配时 LAUNCH 按钮 disabled
- [ ] 启动后 15s 内重新 `loadData()` 反映新状态

### 8.4 视觉
- [ ] 5 级徽章颜色：绿/青/琥珀/黄/红
- [ ] 卡片 `KryptonCard(emphasis: .subtle / .bold)`
- [ ] 数字 `PulseFonts.monoLabel`，标签 `PulseFonts.micro` 大写
- [ ] 圆角 `PulseRadii.sm` / `PulseRadii.md`

### 8.5 i18n
- [ ] `L10n+LiveReadiness.swift` 全部中英双语
- [ ] 切换语言 < 100ms 刷新
- [ ] 无裸英文 / 中文硬编码

## §9 验证命令

```bash
# 后端
cd backend && python3.12 -m pytest tests/test_live_small.py::TestLiveReadinessService -v
# 期望：11 passed

# iOS
cd macos-app && swift build
# 期望：Build complete! 0 error

# 启动 + 路径
GET /api/overview/live-readiness?mode=live_small&strategy_id=v2:btc-scalp&capital_pool_id=cp-1&exchange=binance
# 期望：grand_status=ready_for_live, score=100, can_start_live_small=true

# 启动 + 全空
GET /api/overview/live-readiness?mode=&strategy_id=&capital_pool_id=&exchange=
# 期望：grand_status=needs_config

# 启动 + paper
GET /api/overview/live-readiness?mode=paper&strategy_id=s1&capital_pool_id=cp1&exchange=binance
# 期望：grand_status=paper_passed, can_start_paper=true, can_start_live_small=false
```

## §10 关键文件路径

| 类型 | 路径 |
|---|---|
| 后端 service | `backend/app/services/live_readiness_service.py` |
| 后端 router | `backend/app/routers/overview.py` (`/live-readiness`) |
| 后端 schema | `backend/app/schemas/overview.py` (`LiveReadinessResponse`) |
| 后端测试 | `backend/tests/test_live_small.py::TestLiveReadinessService` |
| iOS 数据 | `macos-app/AlphaLoop/Services/APIOverview.swift` |
| iOS VM | `macos-app/AlphaLoop/ViewModels/LiveReadinessViewModel.swift` |
| iOS 视图 | `macos-app/AlphaLoop/Views/LiveReadiness/LiveReadinessView.swift` |
| iOS i18n | `macos-app/AlphaLoop/Localization/L10n+LiveReadiness.swift` |
