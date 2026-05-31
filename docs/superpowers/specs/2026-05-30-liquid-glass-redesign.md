# Liquid Glass 系统级材质重构

**日期**: 2026-05-30
**范围**: macOS-app PulseDesk 设计系统 + 所有使用玻璃效果的视图
**目标**: 将 Liquid Glass 从"覆盖层"重构为"系统级材质"，让玻璃真正成为容器本身的质感

---

## 问题

当前实现将 `.glassEffect()` 作为装饰层叠加在已有的 surface color 上，然后又在玻璃上方叠加 tint 和描边，导致：

1. **玻璃被遮蔽** — `SidebarView` 和 `ToolbarView` 在 `.glassEffect()` 上叠加 `PulseGlass.surfaceTint`（40% 不透明度深色矩形），完全遮掉了玻璃的透明质感
2. **描边压在玻璃上** — `CardModifier` 和 `DepthCard` 在 `.glassEffect()` 上叠 accent 描边 overlay，玻璃效果被视觉噪声覆盖
3. **圆角过大** — 所有卡片统一 8pt，Liquid Glass 自带柔和边缘，不需要那么大的圆角

## 设计原则

**Liquid Glass 是材质，不是装饰。** 玻璃本身就是容器的材质，颜色和层次由内容和极淡的 tint 决定。

## 玻璃层级体系

| 层级 | 用途 | 实现 |
|------|------|------|
| 结构性玻璃 | 侧边栏、工具栏、设置导航 | `.glassEffect()` + 10% tint |
| 内容卡片 | KPI、图表容器、列表 | `.glassEffect()` + hover 时 1px accent 边框 |
| 交互式玻璃 | 可点击卡片、命令面板 | `.glassEffect(.regular.interactive())` + hover accent 边框 |
| 浮层玻璃 | Toast、弹窗 | `.glassEffect()` + accent 边框 |

## 具体变更

### 1. DesignTokens.swift

**圆角系统** — 整体缩小：
- `PulseRadii.card`: 8 → **4**
- `PulseRadii.lg`: 12 → **8**
- `PulseRadii.sm`: 4 → **3**
- `PulseRadii.md`: 8 → **6**
- 其余不变（xs=2, badge=2, button=2, circle=999）

**Glass Tokens**：
- `PulseGlass.surfaceTint`: 40% → **10%**（极淡，仅区分结构性层次）
- `PulseGlass.accentBorder`: 保持 15%（仅用于 hover/浮层）
- `PulseGlass.accentBorderHover`: 保持 30%
- 新增 `PulseGlass.subtleBorder = Color.white.opacity(0.06)`（默认玻璃边框，非 accent）

### 2. ViewModifiers.swift

**GlassModifier**（侧边栏/工具栏用）：
```swift
// 当前：glassEffect + 40% surfaceTint 矩形 overlay
// 改为：glassEffect + 10% surfaceTint 矩形 overlay
struct GlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect()
            .overlay(
                Rectangle()
                    .fill(PulseGlass.surfaceTint)  // 现在是 10%
                    .allowsHitTesting(false)
            )
    }
}
```

**CardModifier**（内容卡片用）：
```swift
// 当前：glassEffect + 始终显示的 accent 描边
// 改为：glassEffect + 默认无描边（描边由各视图自行控制 hover 状态）
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

**InteractiveGlassModifier** — 不变，已经是 `.glassEffect(.regular.interactive())`

**新增 HoverGlassModifier**（可选，供需要 hover 描边的卡片使用）：
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

暴露为 `.hoverGlassStyle()` View extension。

### 3. SidebarView.swift

- 去掉 `.overlay(Rectangle().fill(PulseGlass.surfaceTint))` — 改用 `.glassStyle()` modifier（它现在只有 10% tint）
- 选中项背景 `PulseColors.accent.opacity(0.1)` 保持，它在玻璃上自然呈现
- 圆角引用从 `PulseRadii.md` 改为对应新值

### 4. ToolbarView.swift

- 同 SidebarView，去掉手写的 `.glassEffect() + surfaceTint`，改用 `.glassStyle()`

### 5. ProofAlphaComponents.swift — DepthCard

```swift
// 当前：content().padding().background(ZStack { glassEffect + 高光 + 聚光灯 })
// 改为：content().padding().glassEffect() + 聚光灯 overlay + hover 描边
```

变更：
- `.glassEffect()` 从 `background()` ZStack 移出，直接作为 modifier
- 顶部高光线移入 `.overlay()`（在玻璃之上，作为装饰）
- 聚光灯效果保留，作为 `.overlay()` 中的 `GeometryReader + RadialGradient`
- 3D 倾斜保留
- 圆角统一 4pt
- accent 描边改为 hover 时才显示

### 6. SpotlightCard

同 DepthCard 的重构思路：
- `.glassEffect()` 直接作为 modifier
- 聚光灯效果保留在 overlay 中
- hover 描边改为仅 hover 时显示

### 7. StrategyCardView

- 保持 `.glassEffect(.regular.interactive())`
- accent 描边从"始终显示"改为"仅 hover 时显示"
- 已有的 `isHovering` 状态控制描边可见性

### 8. 使用 `.cardStyle()` 的所有视图

这些视图不需要修改代码 — 它们通过 `CardModifier` 自动获得新的玻璃行为：
- EquityCurveChart, ActivityFeedView, PositionsListView, RecentTradesListView
- BacktestConfigView, BacktestView, BacktestResultsView
- 所有 Settings 子视图
- StrategyOverviewTab, ResearchSectionView

### 9. CommandPaletteView

- 保持 `.glassEffect(.regular.interactive())`
- accent 描边保持（浮层需要明确边界）
- 圆角从 `PulseRadii.lg` 改为新值（8pt）

### 10. LandingView

- CTA 按钮容器的 `.glassEffect()` 保持
- 圆角调整

## 不变的部分

- `GlassEffectContainer` 在 AppShellView 的包裹
- 动画系统（PulseAnimation）
- 字体系统（PulseFonts）
- 间距系统（PulseSpacing）
- 背景层（BackgroundLayersView）— 玻璃会自然透出它
- `.glassEffectID()` morphing API 预留
- 语义颜色（profit/loss/warning 等）

## 验证标准

1. 侧边栏玻璃可透视背景层的 mesh gradient 和扫描线
2. 卡片内容清晰可读，不被 tint 或描边遮蔽
3. hover 卡片时 accent 描边优雅出现
4. 圆角整体缩小，UI 更紧凑精致
5. `swift build` 通过
