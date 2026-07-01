---
title: BacktestLab — 数据终端风重设计（2026-07-01）
status: draft
date: 2026-07-01
authors: claude (product design)
supersedes:
  - docs/superpowers/specs/2026-06-30-backtest-sim-deep-refactor-design.md (布局重设计，旧 spec 的三栏布局废弃)
related:
  - docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md (后端契约不变)
---

# BacktestLab — 数据终端风重设计

> **本 spec 取代 [2026-06-30-backtest-sim-deep-refactor-design.md](2026-06-30-backtest-sim-deep-refactor-design.md)** 的三栏布局决策。旧 spec 的后端契约、ViewModel 状态机、mock/live 双模式保持不变；本 spec 仅重设计 macOS 端的布局与视觉。

## 1. 背景与问题

当前 `BacktestLabView`（`macos-app/AlphaLoop/Views/BacktestAndDryrun/`）是三栏常驻布局：240pt 左 rail（历史 + compare）+ 中间（tab + config + 结果块）+ 280pt 右 rail（策略元数据 + 风险 + 晋升）。问题：

1. **无主视觉** — 三栏平铺，equity curve 和 trade list 挤在中间栏，没有视觉锚点
2. **信息分散** — 配置、历史、策略元数据常驻占用空间，equity curve 空间不足
3. **不像专业回测工具** — TradingView/Freqtrade/Bloomberg 的回测页都以 equity curve 为主视觉 + 紧凑 metrics + 表格，本页离这个气质远
4. **视觉风格游离** — 刚被改成扁平 surfaceHover + serif italic（沿用 Structure 系列），但回测页是数据工具不是研究文档，应该走深色终端风

## 2. 设计目标

- **A. Equity curve 主视觉** — 360pt 大图，gradient fill + drawdown 标记，占屏幕主视觉
- **B. 顶部 compact bar** — 48pt 单行，run 切换 + backtest/dryrun segmented + New Run + Compare 入口
- **C. 抽屉收起次要信息** — 历史 run 列表、配置表单、策略上下文都收进抽屉/折叠区，不常驻
- **D. 深色终端风** — 深底、大号 mono 数字、gradient curve、紧凑表格、克制状态色
- **E. Metrics 网格** — 2×4 紧凑数据卡，大号 tabular 数字 + 微标签
- **F. Compare 叠加** — 历史 run 勾选 ≥2 后顶部出 Compare 按钮，equity 叠加曲线

## 3. 信息架构

单列全宽，从上到下：

```
┌─────────────────────────────────────────────────────────────────┐
│ Top Bar (48pt)                                                   │
│ [Run #3 · BTC/USDT · 1h · 2026-06-30 ▾]  [Backtest|Dryrun]      │
│                                    [New Run] [Compare (2)]       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Equity Curve (主视觉, 360pt)                                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁  gradient fill + baseline + drawdown 标记│  │
│  │  +50.2% peak        -8.3% max DD                          │  │
│  │  (compare 模式: 多条曲线叠加 + 图例)                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Strategy Context (折叠区, 默认折叠)                              │
│  ▸ BTC Momentum v3 · 5 条风险警告 · 晋升门: 未就绪                │
│                                                                  │
│  Metrics Grid (2×4, 紧凑数据卡)                                  │
│  ┌──────────┬──────────┬──────────┬──────────┐                  │
│  │ +50.2%   │ -8.3%    │ 1.84     │ 64%      │                  │
│  │ 总收益    │ 最大回撤  │ 夏普     │ 胜率     │                  │
│  ├──────────┼──────────┼──────────┼──────────┤                  │
│  │ 1.42     │ 87       │ 2.16     │ 14d 6h   │                  │
│  │ 盈亏比    │ 交易数    │ 利润因子 │ 运行时长  │                  │
│  └──────────┴──────────┴──────────┴──────────┘                  │
│                                                                  │
│  Trade List (表格, 可折叠, 默认展开)                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ #  时间        方向  入场    出场    盈亏    触发规则        │  │
│  │ 1  06-15 14:30 LONG  64200  65800  +1.6%  stop_loss        │  │
│  │ 2  06-15 16:00 SHORT 65800  65100  -0.5%  take_profit      │  │
│  │ ... (前 20 行，"显示全部 87 笔" 按钮)                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

宽度：`frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)`，与 Structure 系列对齐。

### 3.1 Top Bar（48pt 常驻）

单行 HStack，从左到右：
- **Run 切换器**（左）：`[Run #3 · BTC/USDT · 1h · 2026-06-30 ▾]` 按钮，点击弹 History 抽屉。显示当前聚焦 run 的摘要
- **Backtest/Dryrun segmented**（中左）：紧凑 segmented control，2 个选项，选中态 accent tint
- **Spacer**
- **New Run 按钮**（右）：主操作按钮，accent 填充，点击弹 New Run 抽屉
- **Compare 按钮**（右）：当 `comparedRunIds.count >= 2` 时显示，带数字 badge，点击进入 compare 模式（equity 叠加）

### 3.2 Equity Curve（主视觉，360pt）

- 单 run 模式：单条曲线，gradient fill（accent → clear），baseline 虚线，peak 标记，max drawdown 区间红色高亮
- Compare 模式：多条曲线叠加，每条不同颜色，右上角图例
- 空态（无 focusedDetail）：深色背景 + 居中提示"选择一个 run 查看结果"
- 加载态：skeleton shimmer

### 3.3 Strategy Context（折叠区，默认折叠）

点击展开后显示：
- 策略名 + 描述
- 风险警告列表（原 `RiskWarningsPanel`）
- 晋升门状态（原 `PromotionGatePanel`）+ "查看详情" → 跳 `.liveReadiness`

折叠态单行：`▸ BTC Momentum v3 · 5 条风险警告 · 晋升门: 未就绪`

### 3.4 Metrics Grid（2×4）

8 个数据卡，每个：
- 大号 mono 数字（`PulseFonts.tabular` 22pt semibold）
- 微标签（`PulseFonts.micro` 9pt，`colors.textMuted`）
- 数字颜色：正值 accent，负值 danger，中性 textPrimary
- 卡片：`surfaceHover.opacity(0.35)` + border，`PulseRadii.sm`，padding `PulseSpacing.md`

8 个指标（从后端 `result` 提取）：
1. 总收益（total_return）
2. 最大回撤（max_drawdown，danger 色）
3. 夏普比率（sharpe）
4. 胜率（win_rate，百分比）
5. 盈亏比（profit_factor 或 win/loss ratio）
6. 交易数（trade_count）
7. 利润因子（profit_factor，gross profit / gross loss）
8. 运行时长（duration，格式化成 "14d 6h"）

### 3.5 Trade List（表格，可折叠）

- 表头行：`#` `时间` `方向` `入场` `出场` `盈亏` `触发规则`，`PulseFonts.monoLabel`，`colors.textMuted`
- 数据行：`PulseFonts.tabular`，行高 32pt
  - 方向：LONG → accent，SHORT → danger
  - 盈亏：正 → accent，负 → danger
- 默认显示前 20 行 + "显示全部 N 笔" 按钮（展开后全量显示，可滚动）
- 折叠态：只显示表头 + "N 笔交易" 摘要
- 空态："无成交记录"

### 3.6 抽屉

**New Run 抽屉**（右侧滑入，420pt）：
- symbol picker（复用现有 SymbolPicker 模式）
- timeframe segmented
- 策略选择（dropdown 或列表）
- 参数表单（取决于策略 DSL）
- "Run Backtest" / "Run Dryrun" 按钮（按当前 tab）
- 关闭：X 按钮 / ESC / 点击 backdrop

**History 抽屉**（右侧滑入，420pt）：
- 完整 run 列表（backtest 或 dryrun，按当前 tab 过滤）
- 每行前 checkbox（勾选进 compare set）
- 点击行切换聚焦 run
- 顶部搜索框（按 symbol 过滤）
- 底部 "关闭" 按钮

## 4. 视觉风格契约（深色终端风）

与 Structure 系列的扁平研究风**不同**——BacktestLab 是数据工具，走专业终端路线。

| 元素 | 规格 |
|------|------|
| 背景 | `colors.background`（深色） |
| 卡片/面板填充 | `colors.surfaceHover.opacity(0.35)` + `colors.border` 描边 |
| 主视觉 equity | gradient fill `PulseColors.accent → .clear`，drawdown 区间 `PulseColors.danger.opacity(0.2)` |
| 数字字体 | `PulseFonts.tabular`（等宽 mono），大号 22pt semibold |
| 标签字体 | `PulseFonts.micro`（9pt）/ `PulseFonts.monoLabel`（10pt） |
| 表格行高 | 32pt，hover 态 `surfaceHover.opacity(0.5)` |
| 状态色 | 正值 `PulseColors.accent`，负值 `PulseColors.danger`，中性 `colors.textPrimary` |
| 抽屉背景 | `colors.cardBackground` + border + shadow（radius 30, y:12） |
| 顶 bar 高度 | 48pt |
| 圆角 | 卡片 `PulseRadii.md`，按钮 `PulseRadii.button`，徽章 `PulseRadii.badge` |

**不使用**：`.glassEffect()`、`KryptonCard`、serif italic 字体（这些是 Structure 系列的语言，回测页不用）。

## 5. 组件清单

新增/重写组件（全部在 `Views/BacktestAndDryrun/`）：

| 组件 | 职责 | 状态 |
|------|------|------|
| `BacktestLabView` | 根视图，单列布局 + TopBar + 抽屉容器 | 重写 |
| `TopBar/BacktestTopBar.swift` | 48pt 顶 bar：run 切换 + segmented + New Run + Compare | 新增 |
| `TopBar/RunSwitcher.swift` | run 切换器按钮（弹 History 抽屉） | 新增 |
| `Center/EquityCurveHero.swift` | 360pt 主视觉 equity curve + gradient + drawdown + compare 叠加 | 新增（替代 EquityCurveBlock） |
| `Center/StrategyContextStrip.swift` | 折叠区：策略 + 风险 + 晋升门摘要 | 新增（替代右栏三面板） |
| `Center/MetricsGrid.swift` | 2×4 metrics 网格 | 新增（替代 StatusSummaryBlock） |
| `Center/TradeListTable.swift` | 紧凑表格 + 折叠 + 分页 | 新增（替代 TradeListBlock） |
| `Drawers/NewRunDrawer.swift` | 右侧抽屉：配置表单 | 新增（替代 ConfigPanel） |
| `Drawers/HistoryDrawer.swift` | 右侧抽屉：run 列表 + compare checkbox | 新增（替代 RunRailView） |
| `Drawers/DrawerContainer.swift` | 抽屉容器：backdrop + 滑入动画 + ESC 关闭 | 新增 |

**删除**：
- `LeftRail/RunRailView.swift`（逻辑迁入 HistoryDrawer）
- `RightRail/ContextRailView.swift` + `StrategyMetaPanel.swift` + `RiskWarningsPanel.swift` + `PromotionGatePanel.swift`（内容迁入 StrategyContextStrip）
- `Center/ConfigPanel.swift`（迁入 NewRunDrawer）
- `Center/StatusSummaryBlock.swift`（迁入 MetricsGrid）
- `Center/EquityCurveBlock.swift`（迁入 EquityCurveHero）
- `Center/TradeListBlock.swift`（迁入 TradeListTable）
- `Center/CompareBlock.swift`（迁入 EquityCurveHero 的 compare 叠加模式）
- `Shared/SectionCard.swift`（不再需要统一卡片壳）

**保留**：
- `Shared/RiskWarningRules.swift`（纯逻辑 helper）
- `Shared/RunFailureClustering.swift`（纯逻辑 helper）
- `BacktestLabViewModel`（状态机 + selectRun + comparedRunIds + Phase 不变）

## 6. 数据流与状态机

ViewModel 不变，仅 View 层重组：

```
┌──────────────────────────────────────────────┐
│ BacktestLabViewModel (不变)                  │
│  - phase: .idle/.configuring/.running/...    │
│  - activeTab: .backtest/.dryrun              │
│  - currentBacktestRun / currentDryrunRun     │
│  - comparedRunIds: Set<Int>                  │
│  - submittedConfig: RunConfig?               │
│  - recentBacktests / recentDryruns           │
└──────────────────────────────────────────────┘
        ↓ @Environment(vm)
┌──────────────────────────────────────────────┐
│ BacktestLabView (重写)                        │
│  - @State showNewRunDrawer: Bool             │
│  - @State showHistoryDrawer: Bool            │
│  - @State strategyContextExpanded: Bool       │
│  - @State tradeListExpanded: Bool             │
│  - @State compareMode: Bool                  │
└──────────────────────────────────────────────┘
        ↓
   TopBar + EquityCurveHero + StrategyContextStrip
   + MetricsGrid + TradeListTable
   + (NewRunDrawer | HistoryDrawer)?
```

## 7. L10n 新增键

`Localization/L10n+BacktestLab.swift` 追加：

```swift
// Top bar
static var runSwitcherTitle: String { zh("运行 #%d · %@ · %@", en: "Run #%d · %@ · %@") }
static var compare: String { zh("对比", en: "Compare") }

// Metrics
static var metricTotalReturn: String { zh("总收益", en: "Total Return") }
static var metricMaxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
static var metricSharpe: String { zh("夏普", en: "Sharpe") }
static var metricWinRate: String { zh("胜率", en: "Win Rate") }
static var metricProfitLossRatio: String { zh("盈亏比", en: "Profit/Loss") }
static var metricTradeCount: String { zh("交易数", en: "Trades") }
static var metricProfitFactor: String { zh("利润因子", en: "Profit Factor") }
static var metricDuration: String { zh("运行时长", en: "Duration") }

// Strategy context
static var strategyContextCollapsed: String { zh("%@ · %d 条风险警告 · 晋升门: %@", en: "%@ · %d warnings · gate: %@") }
static var showAllTrades: String { zh("显示全部 %d 笔", en: "Show all %d trades") }
static var noTrades: String { zh("无成交记录", en: "No trades") }

// Drawers
static var newRunDrawerTitle: String { zh("新建回测", en: "New Backtest") }
static var historyDrawerTitle: String { zh("历史记录", en: "History") }
```

## 8. 实施分期

| Phase | 内容 | 末尾校验 |
|-------|------|---------|
| **P1 — 骨架 + TopBar** | 重写 `BacktestLabView` 为单列；新增 `BacktestTopBar` + `RunSwitcher`；删除三栏 HStack | `swift build` |
| **P2 — EquityCurveHero** | 新增 `EquityCurveHero`（单 run + compare 叠加）；删 `EquityCurveBlock` + `CompareBlock` | `swift build` |
| **P3 — MetricsGrid + TradeListTable** | 新增 `MetricsGrid`（2×4）+ `TradeListTable`（折叠表格）；删 `StatusSummaryBlock` + `TradeListBlock` | `swift build` |
| **P4 — StrategyContextStrip + Drawers** | 新增 `StrategyContextStrip`（折叠区）+ `NewRunDrawer` + `HistoryDrawer` + `DrawerContainer`；删左右栏 + `ConfigPanel` + `SectionCard` | `swift build` |
| **P5 — L10n + 收尾** | L10n 键；CLAUDE.md 更新；user-guide 更新；旧 spec frontmatter superseded | `swift test` + `swift build` |
| **P6 — 验收** | mock + live 手测；equity 主视觉；抽屉；compare 叠加；metrics 网格；表格折叠 | 手测清单 |

## 9. 验收清单

- [ ] 单列布局，1280 居中，无三栏
- [ ] TopBar 48pt，run 切换器 + segmented + New Run + Compare（≥2 时显示）
- [ ] EquityCurveHero 360pt，gradient fill，drawdown 标记，compare 模式叠加
- [ ] StrategyContextStrip 折叠区，默认折叠，展开后含风险 + 晋升门
- [ ] MetricsGrid 2×4，大号 mono 数字，正负值颜色，微标签
- [ ] TradeListTable 折叠表格，默认展开前 20 行，"显示全部" 按钮
- [ ] NewRunDrawer 右侧滑入，含配置表单 + Run 按钮
- [ ] HistoryDrawer 右侧滑入，含 run 列表 + compare checkbox
- [ ] 深色终端风：surfaceHover + border，无 glass/KryptonCard/serif italic
- [ ] ViewModel 状态机不变，selectRun/comparedRunIds/Phase 逻辑保留
- [ ] L10n zh/en 双语
- [ ] CLAUDE.md 更新 BacktestLabView 描述
- [ ] user-guide 更新
- [ ] 旧 spec frontmatter superseded

## 10. 不在本 spec 范围

- 后端 `/api/v2/backtest/*` 契约变更
- ViewModel 状态机重构
- 新增 metrics 计算（仅展示后端已有字段）
- 自定义 equity 曲线交互（缩放/拖拽/十字线）—— 后续 spec
- 回测报告导出（PDF/CSV）—— 后续 spec
- 策略 DSL 编辑器（NewRunDrawer 只消费策略，不编辑）
