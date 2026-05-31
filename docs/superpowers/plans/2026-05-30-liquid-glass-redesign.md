# Liquid Glass 系统级材质重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Liquid Glass 从"覆盖层装饰"重构为"系统级材质"，让玻璃真正成为容器本身的质感，去掉遮蔽内容的 tint overlay，缩小圆角。

**Architecture:** 修改设计系统 tokens（圆角、tint 浓度），重构 ViewModifiers（CardModifier 去描边、GlassModifier 降 tint、新增 HoverGlassModifier），然后逐个更新使用玻璃效果的视图。`.cardStyle()` 的调用方无需修改，自动继承新行为。

**Tech Stack:** SwiftUI, macOS 26+ Liquid Glass API (.glassEffect, GlassEffectContainer)

**Spec:** `docs/superpowers/specs/2026-05-30-liquid-glass-redesign.md`

---

### Task 1: DesignTokens — 圆角与 Glass Tokens

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/DesignTokens.swift:90-109`

- [ ] **Step 1: 更新圆角系统**

将 `PulseRadii` 的 card/lg/sm/md 值缩小：

```swift
struct PulseRadii {
    static let xs: CGFloat = 2
    static let sm: CGFloat = 3      // was 4
    static let md: CGFloat = 6      // was 8
    static let card: CGFloat = 4    // was 8
    static let lg: CGFloat = 8      // was 12
    static let badge: CGFloat = 2
    static let button: CGFloat = 2
    static let circle: CGFloat = 999
}
```

- [ ] **Step 2: 更新 Glass Tokens**

降低 `surfaceTint` 浓度，新增 `subtleBorder`：

```swift
struct PulseGlass {
    static let accentOverlay = PulseColors.accent.opacity(0.06)
    static let accentBorder = PulseColors.accent.opacity(0.15)
    static let accentBorderHover = PulseColors.accent.opacity(0.30)
    static let surfaceTint = PulseColors.background.opacity(0.10)  // was 0.40
    static let subtleBorder = Color.white.opacity(0.06)
    static let cornerRadius: CGFloat = PulseRadii.card
}
```

- [ ] **Step 3: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED（token 值变更不影响编译）

---

### Task 2: ViewModifiers — 重构玻璃修饰器

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/ViewModifiers.swift:7-50, 150-187`

- [ ] **Step 1: 重写 CardModifier**

去掉始终显示的 accent 描边，让 `.cardStyle()` 只提供玻璃材质 + padding：

```swift
struct CardModifier: ViewModifier {
    var padding: CGFloat = PulseSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }
}
```

- [ ] **Step 2: 重写 GlassModifier**

保持 `.glassEffect()` + 极淡 tint（现在 surfaceTint 已是 10%）：

```swift
struct GlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect()
            .overlay(
                Rectangle()
                    .fill(PulseGlass.surfaceTint)
                    .allowsHitTesting(false)
            )
    }
}
```

代码不变，但 `PulseGlass.surfaceTint` 已从 40% 降到 10%，效果自动生效。

- [ ] **Step 3: 新增 HoverGlassModifier**

为需要 hover 描边的卡片提供可复用修饰器：

```swift
struct HoverGlassModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive())
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(
                        isHovering ? PulseGlass.accentBorderHover : Color.clear,
                        lineWidth: 1
                    )
            )
            .onHover { hovering in
                withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
            }
    }
}
```

- [ ] **Step 4: 添加 View extension**

在 `View` extension 中添加 `.hoverGlassStyle()`：

```swift
func hoverGlassStyle() -> some View {
    modifier(HoverGlassModifier())
}
```

- [ ] **Step 5: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 3: SidebarView — 统一使用 .glassStyle()

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/SidebarView.swift:53-59`

- [ ] **Step 1: 替换手写的 glass+tint 为 .glassStyle()**

当前代码（第 53-59 行）：
```swift
.frame(width: appState.sidebarCollapsed ? 56 : 232)
.glassEffect()
.overlay(
    Rectangle()
        .fill(PulseGlass.surfaceTint)
        .allowsHitTesting(false)
)
```

替换为：
```swift
.frame(width: appState.sidebarCollapsed ? 56 : 232)
.glassStyle()
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 4: ToolbarView — 统一使用 .glassStyle()

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/ToolbarView.swift:80-87`

- [ ] **Step 1: 替换手写的 glass+tint 为 .glassStyle()**

当前代码（第 80-87 行）：
```swift
.frame(height: 48)
.glassEffect()
.overlay(
    Rectangle()
        .fill(PulseGlass.surfaceTint)
        .allowsHitTesting(false)
)
```

替换为：
```swift
.frame(height: 48)
.glassStyle()
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 5: SettingsView — 导航面板玻璃更新

**Files:**
- Modify: `macos-app/PulseDesk/Views/Settings/SettingsView.swift:33-35`

- [ ] **Step 1: 替换 .glassEffect() 为 .glassStyle()**

当前代码（第 33-35 行）：
```swift
.frame(width: 180)
.padding(PulseSpacing.md)
.glassEffect()
```

替换为：
```swift
.frame(width: 180)
.padding(PulseSpacing.md)
.glassStyle()
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 6: ProofAlphaComponents — DepthCard 与 SpotlightCard 重构

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift:7-95, 97-145`

- [ ] **Step 1: 重构 DepthCard**

将 `.glassEffect()` 从 `background()` ZStack 移出，直接作为 modifier。保留 3D 倾斜和聚光灯效果，描边改为 hover 时才显示。

替换整个 `DepthCard` struct（第 7-95 行）：

```swift
struct DepthCard<Content: View>: View {
    let content: () -> Content
    var maxRotation: Double = 3.5
    var spotlightColor: Color = PulseColors.accent.opacity(0.08)

    @State private var rotateX: Double = 0
    @State private var rotateY: Double = 0
    @State private var spotlightX: CGFloat = 0
    @State private var spotlightY: CGFloat = 0
    @State private var spotlightOpacity: Double = 0
    @State private var isHovering = false

    var body: some View {
        content()
            .padding(PulseSpacing.md)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .overlay(
                ZStack {
                    // 顶部高光线
                    VStack {
                        LinearGradient(
                            colors: [.clear, PulseColors.accent.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 1)
                        Spacer()
                    }

                    // 聚光灯叠加层
                    GeometryReader { geo in
                        RadialGradient(
                            colors: [spotlightColor, .clear],
                            center: UnitPoint(
                                x: spotlightX / max(geo.size.width, 1),
                                y: spotlightY / max(geo.size.height, 1)
                            ),
                            startRadius: 0,
                            endRadius: 180
                        )
                        .opacity(spotlightOpacity)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(
                        isHovering ? PulseGlass.accentBorderHover : Color.clear,
                        lineWidth: 1
                    )
            )
            .rotation3DEffect(
                .degrees(rotateX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(rotateY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .animation(PulseAnimation.easeOutFast, value: isHovering)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    isHovering = true
                    spotlightX = point.x
                    spotlightY = point.y
                    spotlightOpacity = 1
                    if let window = NSApp.windows.first {
                        let viewSize = window.frame.size
                        let normalizedX = point.x / max(viewSize.width, 1) - 0.5
                        let normalizedY = point.y / max(viewSize.height, 1) - 0.5
                        rotateY = normalizedX * maxRotation * 2
                        rotateX = -normalizedY * maxRotation * 2
                    }
                case .ended:
                    isHovering = false
                    spotlightOpacity = 0
                    rotateX = 0
                    rotateY = 0
                }
            }
    }
}
```

- [ ] **Step 2: 重构 SpotlightCard**

替换整个 `SpotlightCard` struct（第 97-145 行）：

```swift
struct SpotlightCard<Content: View>: View {
    let content: () -> Content
    var spotlightColor: Color = PulseColors.accent.opacity(0.10)

    @State private var position: CGPoint = .zero
    @State private var isHovered = false

    var body: some View {
        content()
            .padding(PulseSpacing.md)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .overlay(
                GeometryReader { geo in
                    RadialGradient(
                        colors: [spotlightColor, .clear],
                        center: UnitPoint(
                            x: position.x / max(geo.size.width, 1),
                            y: position.y / max(geo.size.height, 1)
                        ),
                        startRadius: 0,
                        endRadius: 200
                    )
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: isHovered)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(
                        isHovered ? PulseGlass.accentBorderHover : Color.clear,
                        lineWidth: 1
                    )
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    position = point
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }
}
```

- [ ] **Step 3: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 7: StrategyCardView — Hover 时才显示描边

**Files:**
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyCardView.swift:89-98`

- [ ] **Step 1: 修改描边逻辑**

当前代码（第 89-98 行）始终显示 accent 描边。改为仅 hover 时显示：

```swift
.padding(PulseSpacing.md)
.glassEffect(.regular.interactive())
.clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
.overlay(
    RoundedRectangle(cornerRadius: PulseRadii.card)
        .stroke(isHovering ? PulseGlass.accentBorderHover : Color.clear, lineWidth: 1)
)
.scaleEffect(isHovering ? 1.01 : 1.0)
.onHover { hovering in
    withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
}
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 8: CommandPaletteView — 圆角更新

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/CommandPaletteView.swift:71-76`

- [ ] **Step 1: 更新命令面板圆角**

当前代码（第 71-76 行）用 `PulseRadii.lg`（12pt），改为新值（8pt）并加 clipShape：

```swift
.frame(width: 480)
.glassEffect(.regular.interactive())
.clipShape(RoundedRectangle(cornerRadius: PulseRadii.lg))
.overlay(
    RoundedRectangle(cornerRadius: PulseRadii.lg)
        .stroke(PulseGlass.accentBorder, lineWidth: 1)
)
```

注意：`PulseRadii.lg` 已从 12pt 降为 8pt，所以这里自动生效。加 `clipShape` 确保内容不超出圆角。

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 9: ToastView — 去掉始终描边

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/ToastView.swift:39-44`

- [ ] **Step 1: Toast 改为无描边玻璃**

Toast 是浮层，保留 `.glassEffect()` 但去掉 accent 描边（玻璃本身已有边缘）：

```swift
.padding(PulseSpacing.sm)
.glassEffect()
.clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 10: Metric Cards — BacktestResultsView 与 StrategyOverviewTab

**Files:**
- Modify: `macos-app/PulseDesk/Views/Backtest/BacktestResultsView.swift:66-71`
- Modify: `macos-app/PulseDesk/Views/Strategies/StrategyOverviewTab.swift:74-79`

- [ ] **Step 1: BacktestResultsView metricCard 去描边**

当前代码（第 66-71 行）：
```swift
.glassEffect()
.overlay(
    RoundedRectangle(cornerRadius: PulseRadii.md)
        .stroke(PulseGlass.accentBorder, lineWidth: 1)
)
```

替换为：
```swift
.glassEffect()
.clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
```

- [ ] **Step 2: StrategyOverviewTab metricCard 去描边**

当前代码（第 74-79 行）：
```swift
.glassEffect()
.overlay(
    RoundedRectangle(cornerRadius: PulseRadii.card)
        .stroke(PulseGlass.accentBorder, lineWidth: 1)
)
```

替换为：
```swift
.glassEffect()
.clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
```

- [ ] **Step 3: 构建验证**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

---

### Task 11: 最终构建验证

**Files:**
- None (verification only)

- [ ] **Step 1: 清理构建**

Run: `cd macos-app && swift package clean && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: 检查无遗漏的 glassEffect + surfaceTint 组合**

Run: `cd macos-app && grep -rn "surfaceTint" PulseDesk/ --include="*.swift"`
Expected: 只出现在 `DesignTokens.swift`（定义）和 `ViewModifiers.swift`（GlassModifier 使用），不再有视图直接使用 `surfaceTint`

- [ ] **Step 3: 检查无遗漏的始终显示描边**

Run: `cd macos-app && grep -rn "accentBorder[^H]" PulseDesk/Views/ --include="*.swift"`
Expected: 只有 CommandPaletteView（浮层保留）和 ProofAlphaComponents BadgeDot（独立组件，不受影响）
