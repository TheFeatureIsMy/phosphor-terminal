---
title: Strategy Workbench — Launch Console Redesign
status: draft
date: 2026-06-11
authors: claude (frontend-design skill)
supersedes: none
related:
  - docs/architecture/phases/phase_03_strategy_workspace_and_canvas.md
  - docs/architecture/13_strategyruledsl_semantics_v2_5.md
  - docs/product/ia_backend_redesign.md (§5.1, §5.2)
  - docs/superpowers/specs/2026-06-07-krypton-pro-ui-overhaul-design.md
mockup: docs/ui-references/mockups/strategy-workbench-v2.html
---

# Strategy Workbench — Launch Console

## 1. Problem

当前实现 (`Views/Strategies/StrategyDetailView.swift`, `Views/Canvas/StrategyCanvasPageView.swift`) 有以下硬伤：

- **画布白屏**: `CanvasWebView.swift:21` 使用 `Bundle.module`，app target 取不到 SPM 资源 bundle。WebView 加载失败。
- **IA 错乱**: 详情页平铺 10 个 Tab（概览/DSL/画布/回测/版本/运行记录/信号/模拟/风控/增长）。一个生命周期被切片成 10 个不互联的房间。
- **违反 ADR-002**: 画布作为详情页 Tab 是一级入口；v2.4/v2.5 明确画布是 StrategyVersion 的**编辑模式**，不是平级 Tab。
- **占位泛滥**: `StrategyRiskTab` 硬编码 "Max Drawdown 15%"；`StrategyGrowthTab` 硬编码 SHAP；多个 Tab 调 API 不传 `strategyId`，显示的是全局数据。
- **画布缺壳**: `StrategyCanvasPageView` 自己实现了一套 native CanvasViewModel（含撤销/接线状态机），但 `StrategyCanvasWebTab` 又走 WebView，两套并存互不引用。React Flow 9 类节点未做视觉设计，是默认圆角矩形。
- **后端缺口**: 没有 `GET /api/strategies/{id}/workspace` 聚合接口，前端只能并行拉 6-7 个独立端点拼装。

## 2. Goals

1. 把"策略工作台 + 策略画布"从 IA 视角统一为**生命周期发射控制台**：策略列表 = 候补发射轨道，详情 = 单一控制台视图，画布 = 编辑舱 Modal。
2. 修复画布白屏（根因 `Bundle.module` → `Bundle.main`）。
3. 重设计画布壳 + 9 类节点视觉，React Flow 内核与桥接协议不动。
4. 视觉语言延续 ProofAlpha 暗色玻璃 + 强化"发射控制台"金属/磷光语言（与 `2026-06-07-krypton-pro-ui-overhaul-design.md` 一脉相承）。
5. 所有 mock 占位必须替换为绑定到 `strategyId` 的真实端点（信号/模拟/风控/增长 4 个 Tab）。
6. 增加 `reason_codes` 在 UI 中的一等地位（卡片右下 chip badge + 抽屉详情）。

## 3. Non-Goals

- **不**改 React Flow 内核、bridge.ts 协议、DSL Validator 逻辑。
- **不**实现 PRD 要求的后端 `/api/canvas/compile`、`/api/canvas/publish`、`/api/canvas/templates` 路由（留给后端 phase）。
- **不**实现 `GET /api/strategies/{id}/workspace` 聚合接口（前端继续并行拉，但封装在 `StrategyWorkspaceViewModel` 内部，留好接入位）。
- **不**重写 native CanvasViewModel；只重设计 WebView 路径的壳与节点视觉。
- **不**改全局 Sidebar / AppShell。

## 4. Information Architecture

```
strategyWorkspace (route)
└── StrategyWorkspaceConsoleView (三栏控制台)
    ├── Left rail  · TrackList (220px)
    │   ├── Filter chip group (lifecycle bucket)
    │   ├── Strategy row × N (mini equity spark + status pip)
    │   ├── + New Draft
    │   └── + From Signal
    │
    ├── Center · Console (flex)
    │   ├── HeaderRow
    │   │   ├── StrategyIdentity (name · symbol · TF · source · provider)
    │   │   └── StateBanner (current lifecycle stage + key reason)
    │   ├── LifecycleRail (7 checkpoints, horizontal, prominent)
    │   ├── KpiStrip (4 mini metrics: equity / win / DD / sharpe)
    │   └── SectionGrid (responsive 6 cards)
    │       ├── RuntimeCard         · snapshot + freqtrade heartbeat
    │       ├── VersionsCard        · version list + diff entry
    │       ├── RiskCard            · guards + reason_codes
    │       ├── BacktestsCard       · last 3 runs + sparkline
    │       ├── DryrunCard          · live orders + paper PnL
    │       └── SignalCard          · signals bound to strategy_id
    │
    └── Right · ContextDrawer (340px, collapsible)
        ├── Mode tabs: Decision · Reason · Logs
        ├── Latest Decision Snapshot (json-styled)
        ├── reason_codes feed (timeline)
        └── Quick actions (validate / backtest / dryrun / archive)

strategyCanvas (route, deprecated as page)
→ 改造为 Modal: CanvasEditBaySheet, 由 VersionsCard 的 "Edit Version" 触发
```

### Strategy lifecycle stages (rail)

7 个检查点对齐 `domain/enums.py` 的 9 态状态机，UI 上合并为视觉一致的 7 节点：

| Rail stage    | Backend states               | Color           |
|---------------|------------------------------|-----------------|
| Draft         | `draft`                      | textMuted       |
| Validated     | `validated`                  | accent          |
| Backtested    | `backtested`                 | accent          |
| Paper Run     | `paper_running`              | warning yellow  |
| Paper Passed  | `paper_passed`               | success         |
| Live Pending  | `live_pending`               | orange          |
| Live Small    | `live_small`                 | accent + glow   |
| (Failure)     | `archived` / `rejected`      | danger          |

## 5. Visual Language

### Tone
继承 `2026-06-07-krypton-pro-ui-overhaul-design.md` 的发射控制台体系，**进一步推到 mission-control 浓度**：

- 顶部状态横幅：浅色描边 + 内嵌呼吸光（dry_running 状态时整条 banner 有 1.2s 节奏的 hue shift）。
- 生命周期 Rail：每个 checkpoint 是金属圆环 + 内嵌磷光点。已通过节点亮 accent + 微抖动；当前节点 cyan 心跳光环；未来节点哑色描边。
- Section Card：玻璃面 + 顶部 2px 状态色条（runtime=accent / risk=warning / signal=cyan ...）+ 右上角 reason_codes chip cluster。
- 数据排版：所有数值统一 mono (SF Mono / IBM Plex Mono)，整数与小数分色（`12,484` accent，`.32%` muted）。

### Color tokens (delta on top of DesignTokens.swift)

新增（如果不存在则补到 `DesignTokens.swift`，否则复用）：

```
PulseColors.accent          #00FF9D
PulseColors.cyan            #5BD4FF
PulseColors.warningAmber    #FFB547
PulseColors.danger          #FF5A6E
PulseColors.purple          #A877FF  // dryrun / paper
PulseColors.background      #07090C
PulseColors.surface         #0E1216
PulseColors.surfaceElevated #131922
PulseColors.border          #1F2731
PulseColors.borderHot       rgba(0,255,157,0.35)
```

### Typography

```
Display heading  · Space Grotesk 600 · 22/28
Console label    · IBM Plex Mono 500 · 11/14 · letter-spacing 0.06em uppercase
KPI tabular      · IBM Plex Mono 500 · 28/32
Body             · Inter 400 · 13/20  (fallback to system)
```

### Motion

- Lifecycle rail current node: 1.6s cyan halo, sin-ease.
- Card mount: 200ms stagger fade-up (24ms per card).
- Drawer open: 220ms ease-out.
- Canvas modal: backdrop fade + sheet scale 0.97 → 1.

## 6. Canvas Edit Bay (modal)

### Frame

```
┌──────────────────────────────────────────────────────────────────────┐
│ EDIT BAY · {strategy.name}                                  ⌘+S  [×]│  56px topbar
│ v3 (draft) · hash 4f7a..b209 · unsaved ●  · DSL v2.5                │
├──────────────────────────────────────────────────────────────────────┤
│ Palette │                                                │ Inspector│
│ (72px)  │            React Flow Canvas (flex)           │ (320px)  │
│ ┌─SIG─┐ │                                                │ ─ Node ─ │
│ │ ◉   │ │                                                │ params   │
│ └─────┘ │                                                │          │
│ ┌─IND─┐ │                                                │ ─ DSL ── │
│ │ ◉   │ │                                                │ preview  │
│ └─────┘ │                                                │ (mono)   │
│  ...    │                                                │          │
│         │                                                │ ─ Valid─ │
│         │                                                │ errors → │
│         │                                                │ click→   │
│         │                                                │ focus    │
├─────────┴────────────────────────────────────────────────┴──────────┤
│ Validation rail: ✓ schema · ✗ missing RiskPolicy · ⓘ shadow guard  │  40px bottom
│         [ Validate ] [ Save Draft ] [ Save & Publish v4 ]           │
└──────────────────────────────────────────────────────────────────────┘
```

### Node visual system

9 节点 (SignalInput, IndicatorCondition, Filter, PositionSizing, RiskPolicy, ExecutionOutput, StructureDefense, AccountRisk, MTFGuard) 统一卡片骨架：

```
┌─────────────────────────────┐
│ ◉ SIG · BTC/USDT · 5m       │  ← 12px header strip (status color)
├─────────────────────────────┤
│ source: signal_center        │
│ symbol: BTC/USDT             │  ← mono body
│ tf:     5m                   │
├─────────────────────────────┤
│ ▲ in    ↓ out                │  ← three-port row (input/output/control)
└─────────────────────────────┘
```

- 节点宽 220px，固定。头部 strip 颜色按节点分类：
  - SIG / IND / Filter → cyan
  - PositionSizing / Execution → accent
  - Risk / Account / StructureDefense → amber
  - MTFGuard → purple (control plane)
- 选中节点：border → borderHot + 4px outer glow。
- 校验失败节点：左侧 3px 红条 + 节点底部 inline error。

### Edges

- 默认 edge: 2px gradient (头节点色 → 尾节点色)，无标签。
- MTFGuard edge: 已有 `MTFGuardEdge` pulse 动画，保留并加 dashed 描边以区分 control plane。

## 7. Component Map (Swift)

```
Views/Strategies/
├── StrategyWorkspaceConsoleView.swift          (new, 替代 StrategiesListView 入口)
├── Components/
│   ├── StrategyTrackList.swift                 (new)
│   ├── ConsoleHeaderRow.swift                  (new)
│   ├── LifecycleRailV2.swift                   (new, 替代旧 StrategyLifecycleRailView)
│   ├── ConsoleKpiStrip.swift                   (new)
│   ├── RuntimeCard.swift                       (new)
│   ├── VersionsCard.swift                      (new)
│   ├── RiskCard.swift                          (rebuild from StrategyRiskTab)
│   ├── BacktestsCard.swift                     (rebuild)
│   ├── DryrunCard.swift                        (rebuild)
│   ├── SignalCard.swift                        (rebuild)
│   ├── ContextDrawer.swift                     (new)
│   ├── ReasonChipCluster.swift                 (new, 复用到全 App)
│   └── DecisionSnapshotInspector.swift         (new)
├── Modals/
│   └── CanvasEditBaySheet.swift                (new, 替代 StrategyCanvasPageView 作为入口)
└── ViewModels/
    └── StrategyWorkspaceViewModel.swift        (new aggregator)

Views/Canvas/
├── CanvasWebView.swift                         (fix: Bundle.main)
├── CanvasEditBayTopBar.swift                   (new)
├── CanvasNodePaletteRail.swift                 (new, 72px vertical)
├── CanvasInspectorPanel.swift                  (new, 320px right)
└── CanvasValidationRail.swift                  (new, bottom 40px)

Resources/canvas-web/
└── (rebuilt) NodeCard.css / NodeBadge.tsx       (节点视觉重设计在 canvas-web 内)
```

## 8. Data Flow

`StrategyWorkspaceViewModel` 用 `async let` 并行拉以下端点（封装在一个 `WorkspaceSnapshot` 结构里）：

```swift
async let strategy   = APIStrategiesV2.get(strategyId)
async let versions   = APIStrategiesV2.listVersions(strategyId)
async let runs       = APIStrategyRuns.listRuns(strategyId: strategyId)        // 必须传 strategyId
async let signals    = APISignals.list(strategyId: strategyId, limit: 20)      // 必须传 strategyId
async let snapshot   = APIDecision.snapshot(strategyId, symbol, tf)
async let risk       = APIRisk.overview(strategyId: strategyId)
async let backtests  = APIBacktest.list(strategyId: strategyId, limit: 3)
```

如果未来后端实现 `GET /api/strategies/{id}/workspace`，把 7 个 async let 合并为单一调用，ViewModel 对 View 暴露的 `WorkspaceSnapshot` 接口不变。

### Mock generators 必备 (按 CLAUDE.md 约定)

每个 API service 文件**必须新增**对应的 `MockX.workspaceXxx()` 工厂，否则 `MockNetworkClient` 拿不到数据：

- `APIStrategiesV2.swift` + `MockStrategy.workspaceSnapshot()`
- `APIRisk.swift` + `MockRisk.strategyOverview(strategyId)`
- `APIBacktest.swift` + `MockBacktest.listByStrategy(strategyId)`

## 9. State & reason_codes contract

每张 section card 右上角固定 ReasonChipCluster：

```swift
struct ReasonChip: Hashable {
    let code: String          // "snapshot_fresh" / "shadow_warning"
    let severity: Severity    // info / warn / block
}
```

抽屉 Reason Tab 全量展示，并支持点击 chip 反向高亮触发节点（画布开启时）。

## 10. Routing changes

```swift
// Models/Enums.swift  AppRoute
case strategyWorkspace      // 入 StrategyWorkspaceConsoleView (含 list+detail 三栏)
// case strategyDetail       // 删除 — 合并进 console
// case strategyCanvas        // 保留 enum 以兼容旧 deep link，但视图改为打开 Modal 后回弹
```

侧边栏依然 3 项 (`Strategy Workspace / Canvas / Backtest`)，但 Canvas 项行为变更：点击时若有 selectedStrategyId 则打开 EditBay sheet，否则跳回 console 提示先选择策略。

## 11. Acceptance Criteria

1. **画布**: 启动 app → 选任一策略 → 点击 VersionsCard 的 Edit → Modal 打开 React Flow 节点可见可拖（不再白屏）。
2. **IA**: 策略详情不再有 10 个 Tab；section 卡片在 1440 宽布局下 3 列 × 2 行响应式可见。
3. **reason_codes**: 每张 section card 右上角至少展示一个 chip（来自后端或 mock）。
4. **strategyId 绑定**: 信号/模拟/风控/增长 4 个旧 Tab 升级为 card 时，全部按 strategyId 过滤数据。
5. **L10n**: 所有用户可见文案走 `L10n.Workbench.*` keys，新增 `L10n+Workbench.swift`。
6. **视觉**: 颜色/字体/间距全部走 DesignTokens；不引入硬编码值。
7. **mockup**: `docs/ui-references/mockups/strategy-workbench-v2.html` 在 macOS Safari 1440×900 全屏下视觉与 Swift 实现差异 < 5%。

## 12. Out of scope (future)

- `GET /api/strategies/{id}/workspace` BFF 聚合（后端 phase）。
- `/api/canvas/{compile, publish, templates}` 路由组（后端 phase）。
- 画布节点编译/cycle 检测增强（DSL 当前仅 schema 校验）。
- 模板库实际加载（按钮已挂在 EditBay topbar，但不绑动作）。
- 跨策略 diff / 多策略对比 (P3)。
