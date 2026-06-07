# Krypton Pro macOS UI 全面优化 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 全面提升 PulseDesk macOS SwiftUI 应用的 UI 品质 — 清理废弃组件、统一排版、增强动效、一致化加载/空/错误态。

**Architecture:** 分层重构策略。先升级设计系统（PulseFonts/动画预设/组件清理），再增强共享组件库，然后逐功能域迁移视图。所有视图通过 KryptonCard + PulseFonts + 统一加载/空态组件实现一致性。

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14+, Liquid Glass (macOS 26), no external dependencies

---

## File Structure Map

| 层 | 文件 | 职责 |
|----|------|------|
| 设计令牌 | `DesignSystem/DesignTokens.swift` | 色彩/字体/间距/动画预设 |
| 字体扩展 | `DesignSystem/FontExtensions.swift` | 便捷字体工厂方法 |
| 视图修饰器 | `DesignSystem/ViewModifiers.swift` | CardModifier, GlassModifier, Shimmer 等 |
| 动效组件 | `DesignSystem/AnimatedEffects.swift` | DecryptedText, CountUp, PulseRing 等 |
| 核心组件 | `Views/Shared/ProofAlphaComponents.swift` | KryptonCard, TerminalLabel, BadgeDot, KryptonButton 等 |
| 表单控件 | `Views/Shared/FormControls.swift` | PulseTextField, PulseSecureField, PulseToggle 等 |
| 空态视图 | `Views/Shared/EmptyStateView.swift` | 统一空态展示 |
| 应用入口 | `PulseDeskApp.swift` | WindowGroup, 环境注入, ContentView |
| 应用壳 | `Views/AppShell/AppShellView.swift` | 侧边栏 + 工作区 + 状态栏布局 |
| 侧边栏 | `Views/AppShell/SidebarView.swift` | 48px 极窄侧边栏 + 工作区图标 |
| 工作区标签 | `Views/AppShell/WorkspaceTabBar.swift` | 3 工作区切换标签 |

---

### Task 1.1: 清理 ProofAlphaComponents.swift 废弃组件

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift`

**Purpose:** 移除 `ProofAlphaCard` typealias、`ProofAlphaButton` typealias、`SpotlightCard`、`GlassCard` 四个废弃声明。保留 KryptonCard、KryptonButton、TerminalLabel、BadgeDot、StatusDot、GlowText、GradientText。

- [ ] **Step 1: 移除废弃组件和 typealias**

在 `ProofAlphaComponents.swift` 中删除以下内容：
- 第 8 行: `typealias ProofAlphaCard = KryptonCard`
- 第 163-224 行: `SpotlightCard` struct 完整定义
- 第 227-325 行: `GlassCard` struct 完整定义  
- 第 475 行: `typealias ProofAlphaButton = KryptonButton`

使用以下 Edit 命令（按序执行）:

```swift
// 删除 typealias ProofAlphaCard = KryptonCard (line 8)
// old_string:
typealias ProofAlphaCard = KryptonCard

// new_string: (空，直接删除)

// 删除 SpotlightCard struct (lines 163-224)
// old_string: 从 "// DEPRECATED: Use KryptonCard(emphasis:) instead." 到 SpotlightCard 的 `}` 结束

// 删除 GlassCard struct (lines 227-325)
// old_string: 从 "// DEPRECATED: Use KryptonCard(emphasis:) instead." 到 GlassCard 的 `}` 结束

// 删除 typealias ProofAlphaButton = KryptonButton (line 475)
// old_string:
typealias ProofAlphaButton = KryptonButton

// new_string: (空，直接删除)
```

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | head -50
```

预期: 大量编译错误（45 个文件引用已删除的标识符），确认所有错误都是 "Cannot find 'ProofAlphaCard'" / "Cannot find 'SpotlightCard'" / "Cannot find 'GlassCard'" / "Cannot find 'ProofAlphaButton'"

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift
git commit -m "refactor(ui): remove deprecated SpotlightCard, GlassCard, ProofAlpha typealiases"
```

---

### Task 1.2: PulseFonts 补全 + 动画预设扩展

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/DesignTokens.swift`

- [ ] **Step 1: 在 PulseFonts 中添加缺失变体**

在 `PulseFonts` struct 中（第 143 行 `static let displaySubheading` 之后）插入：

```swift
    static let displayLarge = Font.system(size: 32, weight: .bold)
    static let headline = Font.system(size: 15, weight: .semibold)
    static let label = Font.system(size: 12, weight: .medium)
```

- [ ] **Step 2: 在 PulseAnimation 中添加新预设**

在 `PulseAnimation` struct 中（第 242 行 `static let staggerDelay` 之后）插入：

```swift
    static let workspaceTransition = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let cardEntry = Animation.spring(response: 0.4, dampingFraction: 0.75)
```

- [ ] **Step 3: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -20
```

预期: BUILD SUCCESS（此任务只添加新符号，不破坏现有代码）

- [ ] **Step 4: 提交**

```bash
git add macos-app/PulseDesk/DesignSystem/DesignTokens.swift
git commit -m "feat(ui): add PulseFonts displayLarge/headline/label and workspaceTransition/cardEntry animations"
```

---

### Task 2.1: KryptonCard 增强 — 空态/加载态/错误态

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift`

**Purpose:** 为 KryptonCard 增加 `isEmpty`、`isLoading`、`errorMessage`/`onRetry` 参数支持。

- [ ] **Step 1: 在 KryptonCard 中添加新属性**

在 KryptonCard struct 的 `var emphasis` 声明之后（第 18 行后），`var cardPadding` 之前插入：

```swift
    var isEmpty: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var onRetry: (() -> Void)? = nil
```

- [ ] **Step 2: 修改 body 以支持空态边框样式**

将 body 中的 `overlay(cardBorder)` 替换为条件边框逻辑。修改 `cardBorder` 计算属性，使其在 `isEmpty` 时使用虚线：

```swift
    private var cardBorder: some View {
        if isEmpty {
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(
                    colors.border,
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
        } else {
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(
                    emphasis == .bold
                        ? PulseGlass.accentBorder
                        : PulseGlass.subtleBorder(colors),
                    lineWidth: 1
                )
        }
    }
```

- [ ] **Step 3: 在 body 中添加加载态骨架屏 overlay**

在 body 末尾（`onLongPressGesture` 闭包结束后）添加：

```swift
            .overlay {
                if isLoading {
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface)
                        .shimmer()
                }
            }
            .overlay {
                if let errorMessage {
                    VStack(spacing: PulseSpacing.sm) {
                        HStack(spacing: PulseSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(KryptonColor.red)
                            Text(errorMessage)
                                .font(PulseFonts.body)
                                .foregroundStyle(KryptonColor.red)
                        }
                        if let onRetry {
                            KryptonButton(title: "重试", action: onRetry, style: .ghost)
                        }
                    }
                    .padding(cardPadding)
                }
            }
```

- [ ] **Step 4: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -20
```

预期: 编译通过（可能有 warning 关于 unused 属性，这是正常的 — 新参数还未被使用）

- [ ] **Step 5: 提交**

```bash
git add macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift
git commit -m "feat(ui): add empty/loading/error state variants to KryptonCard"
```

---

### Task 2.2: EmptyStateView 更新 — 使用 KryptonButton 替换废弃按钮

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/EmptyStateView.swift`

- [ ] **Step 1: 替换 ProofAlphaButton 为 KryptonButton**

```swift
// old_string:
                    ProofAlphaButton(title: primaryAction.title, action: primaryAction.action)
// new_string:
                    KryptonButton(title: primaryAction.title, action: primaryAction.action)
```

```swift
// old_string:
                    ProofAlphaButton(title: secondaryAction.title, action: secondaryAction.action, style: .ghost)
// new_string:
                    KryptonButton(title: secondaryAction.title, action: secondaryAction.action, style: .ghost)
```

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Views/Shared/EmptyStateView.swift
git commit -m "refactor(ui): migrate EmptyStateView to KryptonButton"
```

---

### Task 2.3: StatusDot 增强 — warning 状态 + 慢速 idle 脉冲

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift`

- [ ] **Step 1: 在 StatusType 枚举中添加 warning**

将 `StatusDot.StatusType` 改为：

```swift
    enum StatusType {
        case online, offline, loading, warning

        var color: Color {
            switch self {
            case .online: return PulseColors.statusActive
            case .offline: return PulseColors.statusError
            case .loading: return PulseColors.cyan
            case .warning: return PulseColors.warning
            }
        }
    }
```

- [ ] **Step 2: 根据状态调整脉冲速度**

将 StatusDot body 中动画的 duration 参数改为按状态变量：

```swift
    private var pulseDuration: Double {
        switch status {
        case .offline: return 0  // 不脉冲
        case .online, .warning: return 3.6  // 慢速 3x
        case .loading: return 1.2  // 正常速度
        }
    }
```

动画行改为：
```swift
                .animation(
                    .easeOut(duration: pulseDuration)
                    .repeatForever(autoreverses: false),
                    value: isPulsing
                )
```

- [ ] **Step 3: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 4: 提交**

```bash
git add macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift
git commit -m "feat(ui): add warning state and slow idle pulse to StatusDot"
```

---

### Task 3.1: 工作区缩放深度过渡动画

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

**Purpose:** 将 ZStack + opacity 工作区切换替换为缩放深度过渡。

- [ ] **Step 1: 添加 @State 跟踪过渡方向**

在 AppShellView 中添加：

```swift
    @State private var previousWorkspace: PrimaryWorkspace = .tradingConsole
```

- [ ] **Step 2: 替换 workspaceContent**

将 `workspaceContent` 的 ZStack + opacity 替换为：

```swift
    @ViewBuilder
    private var workspaceContent: some View {
        ZStack {
            switch appState.primaryWorkspace {
            case .tradingConsole:
                TradingConsoleRootView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))
            case .strategyLab:
                StrategyLabRootView()
                    .transition(.asymmetric(
                        insertion: previousWorkspace == .tradingConsole
                            ? .move(edge: .trailing).combined(with: .opacity)
                            : .move(edge: .leading).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))
            case .operations:
                OperationsRootView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))
            }
        }
        .animation(PulseAnimation.workspaceTransition, value: appState.primaryWorkspace)
        .onChange(of: appState.primaryWorkspace) { _, newValue in
            previousWorkspace = newValue
        }
    }
```

- [ ] **Step 3: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 4: 提交**

```bash
git add macos-app/PulseDesk/Views/AppShell/AppShellView.swift
git commit -m "feat(ui): add workspace scale-depth transition animation"
```

---

### Task 3.2: 侧边栏打磨 — hoverGlassStyle + accent 发光

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/SidebarView.swift`

- [ ] **Step 1: WorkspaceIconButton 使用 hoverGlassStyle**

将 WorkspaceIconButton label 中的手动 RoundedRectangle 背景替换为 hoverGlassStyle。简化 ZStack：

```swift
            ZStack {
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(.clear)
                    .frame(width: 34, height: 34)

                Image(systemName: workspace.icon)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? KryptonColor.amber : (isHovering ? colors.textPrimary : colors.textMuted))
            }
            .hoverGlassStyle(cornerRadius: PulseRadii.md)
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(KryptonColor.amber)
                        .frame(width: 2, height: 16)
                        .offset(x: -8)
                        .shadow(color: KryptonColor.amber.opacity(0.5), radius: 4)
                }
            }
```

移除外层 overlay 的 trailing border（line 69），因为 hoverGlassStyle 已提供边框。

- [ ] **Step 2: ⌘K 和设置按钮使用 hoverGlassStyle**

将两个底部按钮的 `.background(RoundedRectangle(...).fill(Color.clear))` 替换为 `.hoverGlassStyle(cornerRadius: PulseRadii.md)`。

- [ ] **Step 3: Logo 按钮增加 hover 脉冲光环**

在 Logo 按钮上添加 onHover 驱动 PulseRing：

```swift
            Button {
                appState.selectedRoute = .dashboard
            } label: {
                ZStack {
                    if isLogoHovered {
                        PulseRing(color: PulseColors.accent.opacity(0.6), size: 36)
                    }
                    KryptonLogoView()
                        .frame(width: 24, height: 24)
                }
            }
```

添加 `@State private var isLogoHovered = false`，并给 Logo 按钮添加 `.onHover`。

- [ ] **Step 4: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 5: 提交**

```bash
git add macos-app/PulseDesk/Views/AppShell/SidebarView.swift
git commit -m "feat(ui): polish sidebar with hoverGlassStyle and logo pulse ring"
```

---

### Task 3.3: 全局状态栏打磨

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/GlobalStatusBar.swift`

- [ ] **Step 1: 审计并修复 GlobalStatusBar 中的硬编码字体和组件使用**

读取文件，将硬编码 `.font(.system(...))` 替换为 PulseFonts 变体，状态指示器统一使用 StatusDot。

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Views/AppShell/GlobalStatusBar.swift
git commit -m "refactor(ui): standardize GlobalStatusBar typography and StatusDot usage"
```

---

### Task 4.1: Dashboard 卡片迁移到 KryptonCard

**Files:**
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/BentoEquityCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/PositionsRiskCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/PendingConfirmationsCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/RecentRiskEventsCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/ServiceHealthCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/RiskInterceptionStatsCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/AgentSignalDistributionCard.swift`
- Modify: `macos-app/PulseDesk/Views/Dashboard/Cards/AIMarketJudgmentCard.swift`

**Pattern:** 检查每张卡片当前使用的组件包装。如果使用 `ProofAlphaCard`/`SpotlightCard`/`GlassCard`，替换为 `KryptonCard(emphasis:)`。emphasis 映射：
- `SpotlightCard` → `KryptonCard(emphasis: .balanced)`
- `GlassCard` → `KryptonCard(emphasis: .bold)`
- `ProofAlphaCard` → `KryptonCard(emphasis: .subtle)`（Dashboard 卡片默认 subtle）

- [ ] **Step 1: 逐文件替换**

对每个文件执行：`ProofAlphaCard(` → `KryptonCard(emphasis: .subtle, `; `SpotlightCard(` → `KryptonCard(emphasis: .balanced, `; `GlassCard(` → `KryptonCard(emphasis: .bold, `

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -20
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Views/Dashboard/Cards/
git commit -m "refactor(ui): migrate Dashboard cards to KryptonCard(emphasis:)"
```

---

### Task 4.2: Dashboard 卡片交错入场动画

**Files:**
- Modify: `macos-app/PulseDesk/Views/Dashboard/DashboardView.swift`

- [ ] **Step 1: 为 mainContent 中的卡片添加 staggeredAppearance**

在 `DashboardView` 中添加 `@State private var contentAppeared = false`。

在 `mainContent` 的 VStack 上添加 `.onAppear { contentAppeared = true }`。

将 8 张卡片用 `ForEach(Array(...))` 包装（或手动给 index），每张卡片添加 `.staggeredAppearance(index: index, baseDelay: 0.05)`。

对于第一列（3 张 VStack 卡片），index 0-2。第二列（4 张 VStack 卡片），index 3-6。底部 RecentRiskEventsCard，index 7。

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Views/Dashboard/DashboardView.swift
git commit -m "feat(ui): add staggered card entry animation to Dashboard"
```

---

### Tasks 5.1-5.14: 批量视图迁移

**范围:** 45 个文件，按功能域分批。每批执行相同模式：

**模式（每个文件执行以下操作）:**
1. `ProofAlphaCard(` → `KryptonCard(emphasis: .subtle, `
2. `SpotlightCard(` → `KryptonCard(emphasis: .balanced, `
3. `GlassCard(` → `KryptonCard(emphasis: .bold, `
4. `ProofAlphaButton(` → `KryptonButton(`
5. 硬编码 `.font(.system(size: N, ...))` → 最近似 PulseFonts 变体
6. 列表/集合视图添加 shimmer 加载态
7. 空数据状态添加 EmptyStateView

**批次划分:**

| 任务 | 目录 | 文件数 | 文件列表 |
|------|------|--------|---------|
| 5.1 | Views/Strategies/ | 12 | StrategyCardView, StrategiesListView, StrategyDetailView, StrategyOverviewTab, StrategySignalsTab, StrategyDSLTab, StrategyRiskTab, StrategyDryrunTab, StrategyGrowthTab, StrategyBacktestTab, StrategyRunsTab, StrategyCreatePanel, StrategyVersionsTab, StrategyCanvasWebTab, AIChatView, DSLValidationReportView, BacktestResultCardView |
| 5.2 | Views/Settings/ | 11 | SettingsView, SettingsTabBar, SettingsTab, ProfileSettingsView, ExchangeSettingsView, RiskSettingsView, NotificationSettingsView, APISettingsView, DataVacuumSettingsView, DangerZoneView, McpServerSettingsView |
| 5.3 | Views/Growth/ | 5 | GrowthView, StrategyOptimizationView, FailureClusteringView, GrowthReportCard, CandidateCard |
| 5.4 | Views/Risk/ | 4 | RiskView, RiskCenterView, CircuitBreakersView, StopProtectionView |
| 5.5 | Views/SignalCenter/ + Views/Sentiment/ | 5 | SignalCenterView, SignalCardView, SignalDetailSheet, SentimentView, FearGreedGauge |
| 5.6 | Views/Execution/ + Views/ExecutionRecords/ | 4 | ExecutionCenterView, OrdersPositionsView, ReconciliationBusView, ExecutionRecordsView, ExecutionDetailSheet |
| 5.7 | Views/AIStudio/ + Views/AIProviders/ | 3 | AIStudioView, AIProvidersView, ProviderCardView |
| 5.8 | Views/AgentPlatform/ | 1 | AgentCardView, AgentDetailView |
| 5.9 | Views/DryrunMonitor/ | 2 | DryrunMonitorView, DryrunBotCard |
| 5.10 | Views/Manipulation/ | 2 | ManipulationRadarView, ManipulationScoreRow |
| 5.11 | Views/Structure/ + Views/DataSources/ | 3 | MarketStructureView, StructureMatrixView, DataSourcesView |
| 5.12 | Views/BacktestAndDryrun/ + Views/LiveReadiness/ + Views/Canvas/ | 4 | BacktestDryrunView, LiveReadinessView, StrategyCanvasPageView, CodePreviewSheet |
| 5.13 | Views/Landing/ + Views/Setup/ + PulseDeskApp.swift | 3 | LandingView, SetupWizardView, PulseDeskApp.swift (LoginPlaceholderView) |
| 5.14 | Views/AppShell/ + Views/Notifications/ | 3 | WorkspaceTabBar, NotificationRow, NotificationPopover |

**每个批次的步骤模板:**

- [ ] **Step 1: 组件名称迁移**

对批次中每个文件，将 `ProofAlphaCard`/`SpotlightCard`/`GlassCard`/`ProofAlphaButton` 替换为 KryptonCard/KryptonButton。

- [ ] **Step 2: 硬编码字体替换**

对批次中每个文件，将 `.font(.system(size: N, ...))` 替换为最近似 PulseFonts 变体:
- 28pt+ bold → `PulseFonts.displayLarge`
- 20-27pt semibold → `PulseFonts.displayHeading`  
- 16pt medium → `PulseFonts.displaySubheading`
- 15pt semibold → `PulseFonts.headline`
- 13pt regular → `PulseFonts.body`
- 13pt medium → `PulseFonts.bodyMedium`
- 12pt medium → `PulseFonts.label`
- 11pt → `PulseFonts.caption` / `captionMedium`
- 9-10pt → `PulseFonts.micro` / `monoLabel`

- [ ] **Step 3: 加载态和空态添加**

对包含列表/集合的视图，添加条件分支：
- `if viewModel.isLoading { LoadingSkeleton }`
- `else if viewModel.items.isEmpty { EmptyStateView(...) }`
- `else { contentList }`

- [ ] **Step 4: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -20
```

修复所有编译错误后提交。

- [ ] **Step 5: 提交**

```bash
git add macos-app/PulseDesk/Views/<batch-dir>/
git commit -m "refactor(ui): migrate <batch-name> views to Krypton components and PulseFonts"
```

---

### Task 6.1: glassEffect 全量审计

**Files 审计范围:**
- `macos-app/PulseDesk/DesignSystem/ViewModifiers.swift`
- `macos-app/PulseDesk/Views/Shared/FormControls.swift`

- [ ] **Step 1: 审计 ViewModifiers.swift**

检查所有 `.glassEffect()` 调用：
- `GlassModifier.body` (line 37): ✅ `.glassEffect()` 直接作用于 content
- `ConditionalGlassModifier.body` (line 59, 61): ✅ `.glassEffect()` 直接作用于 content
- `InteractiveGlassModifier.body` (line 72): ✅ `.glassEffect()` 直接作用于 content
- `HoverGlassModifier.body` (line 94): ✅ `.glassEffect()` 直接作用于 content

全部合规。无需修改。

- [ ] **Step 2: 审计 FormControls.swift**

检查所有 `.glassEffect()` 调用：
- `DarkTextFieldModifier.body` (line 19): ✅ 直接作用于 content
- `DarkPickerModifier.body` (line 46): ✅ 直接作用于 content
- `DarkSegmentedPickerModifier.body` (line 63): ✅ 直接作用于 content
- `DarkButtonModifier.body` (line 83): ✅ 直接作用于 content
- `PulseTextField.body` (line 136): ✅ 直接作用于 TextField
- `PulseSecureField.body` (line 173): ✅ 直接作用于 SecureField

全部合规。无需修改。

- [ ] **Step 3: 全量搜索确认无遗漏**

```bash
grep -rn '\.background.*glassEffect\|glassEffect.*\.background' macos-app/PulseDesk/ --include="*.swift"
```

预期: 无输出（确认无 .background 内使用 glassEffect）

```bash
grep -rn '\.glassEffect' macos-app/PulseDesk/ --include="*.swift"
```

预期: 仅 ViewModifiers.swift 和 FormControls.swift 有结果（均已审计）

- [ ] **Step 4: 提交**

```bash
git commit -m "audit(ui): verify all glassEffect usage is direct-on-content (all clean)" --allow-empty
```

（如果审计结果 clean，使用 --allow-empty；如果有修复则正常提交）

---

### Task 7.1: Toast 入场动画增强

**Files:**
- Modify: `macos-app/PulseDesk/Services/ToastManager.swift`

- [ ] **Step 1: 检查 ToastOverlayView 实现并添加 staggered animation**

读取 `ToastManager.swift`，找到 Toast 渲染部分，为每个 Toast 添加：

```swift
.staggeredAppearance(index: index, baseDelay: 0.02)
```

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Services/ToastManager.swift
git commit -m "feat(ui): add staggered entry animation to Toast notifications"
```

---

### Task 7.2: CommandPalette 键盘导航增强

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/CommandPaletteView.swift`

- [ ] **Step 1: 添加上下键选择 + Escape 关闭**

读取文件，添加：
- `@State private var selectedIndex: Int = 0`
- `.onKeyPress(.upArrow)` 和 `.onKeyPress(.downArrow)` 处理
- `.onKeyPress(.escape)` 关闭
- hover 时更新 selectedIndex
- 选中行高亮样式

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/Views/AppShell/CommandPaletteView.swift
git commit -m "feat(ui): add keyboard navigation to CommandPalette"
```

---

### Task 7.3: Shimmer 性能优化 — TimelineView 驱动

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/ViewModifiers.swift`

- [ ] **Step 1: 将 ShimmerModifier 从 repeatForever 改为 TimelineView**

替换 ShimmerModifier 实现：

```swift
struct ShimmerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        let phase = timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1.5) / 1.5
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: phase - 0.3),
                                .init(color: colors.surfaceHover, location: phase),
                                .init(color: .clear, location: phase + 0.3),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + geometry.size.width * 2 * phase)
                    }
                }
                .mask(content)
            )
    }
}
```

移除原有的 `@State private var phase` 和 `onAppear` 闭包。

- [ ] **Step 2: 构建验证**

```bash
cd macos-app && swift build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add macos-app/PulseDesk/DesignSystem/ViewModifiers.swift
git commit -m "perf(ui): migrate Shimmer to TimelineView driver for offscreen efficiency"
```

---

### Task 7.4: 全量构建 + 测试验证

- [ ] **Step 1: 完整构建**

```bash
cd macos-app && swift build 2>&1
```

预期: BUILD SUCCESS，0 errors

- [ ] **Step 2: 运行测试**

```bash
cd macos-app && swift test 2>&1
```

预期: 所有测试通过

- [ ] **Step 3: 全局审计 — 验证废弃组件已清零**

```bash
grep -rn "ProofAlphaCard\|ProofAlphaButton\|SpotlightCard\|GlassCard" macos-app/PulseDesk/ --include="*.swift"
```

预期: 无输出（或仅在 ProofAlphaComponents.swift 中有注释引用）

- [ ] **Step 4: 全局审计 — 验证硬编码字体已清零（排除 PulseFonts 定义和图表内部）**

```bash
grep -rn '\.font(\.system(' macos-app/PulseDesk/ --include="*.swift" | grep -v DesignTokens | grep -v FontExtensions | grep -v Chart | grep -v Canvas | grep -v Shape
```

预期: 仅少数合理例外（如 EquityCurveChart 图表内部标注）

- [ ] **Step 5: 提交**

```bash
git commit -m "verify: full build + tests pass, audit confirmations clean" --allow-empty
```

---

### Task 7.5: 最终清理

- [ ] **Step 1: 检查有无未使用的 import**

```bash
cd macos-app && swift build 2>&1 | grep -i "unused\|warning"
```

修复任何编译 warning。

- [ ] **Step 2: 验证 git status clean**

```bash
git status
```

- [ ] **Step 3: 最终提交**

```bash
git commit -m "chore(ui): final cleanup — remove unused imports, fix warnings" --allow-empty
```

---

## 成功标准验证清单

- [ ] `swift build` 0 errors
- [ ] `swift test` 全部通过
- [ ] 0 处 `ProofAlphaCard`/`ProofAlphaButton`/`SpotlightCard`/`GlassCard` 引用
- [ ] 0 处硬编码 `.font(.system(...))`（排除 DesignTokens/FontExtensions/Chart/Canvas 内部）
- [ ] 0 处 `.background { ... glassEffect() }` 误用
- [ ] 所有列表有 shimmer 加载态
- [ ] 所有集合有空态 EmptyStateView
- [ ] 工作区切换有缩放深度过渡
- [ ] PulseFonts 包含 displayLarge/headline/label
- [ ] PulseAnimation 包含 workspaceTransition/cardEntry
- [ ] StatusDot 有 .warning 状态
