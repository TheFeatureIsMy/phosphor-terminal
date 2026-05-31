# Batch A: Design System Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify card components, fix micro-interactions, redesign loading/empty states, and fix theme bugs — establishing the foundation that Batch B/C/D depend on.

**Architecture:** Merge 3 card components (DepthCard, GlassCard, SpotlightCard) into a single `ProofAlphaCard` with `Emphasis` enum controlling behavior. Fix 3D tilt to use per-card GeometryReader coordinates. Replace DragGesture-based press with TapGesture-based approach to avoid ScrollView conflicts. Add typed skeleton variants to LoadingView. Refine EmptyStateView with spring animation and secondary actions.

**Tech Stack:** SwiftUI, macOS 14+, ProofAlpha design tokens (PulseColors, PulseFonts, PulseSpacing, PulseRadii, PulseAnimation)

---

### Task 1: Add `loss` instance property to PulseColors

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/DesignTokens.swift:56`

**Why:** `PulseColors.loss` is static (always #FF3B3B). In light theme, loss color should adjust alongside profit, but the static property doesn't respond to theme changes. All callers using `PulseColors.loss` need to switch to `colors.loss` (instance).

- [ ] **Step 1: Add instance property and keep static for backward compat**

In `DesignTokens.swift`, after the existing `static let loss` line (line 56), add an instance computed property:

```swift
// DesignTokens.swift — inside PulseColors class, replace line 56:

// Remove:
//     static let loss = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B

// Replace with:
    static let loss = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B (legacy static)
    var loss: Color {
        isDark
            ? Color(red: 1.0, green: 0.231, blue: 0.231)  // #FF3B3B — dark
            : Color(red: 0.85, green: 0.15, blue: 0.15)    // dimmer red for light theme
    }
```

- [ ] **Step 2: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds (no errors from this change alone)

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/DesignSystem/DesignTokens.swift
git commit -m "$(cat <<'EOF'
fix(design): add theme-responsive loss color instance property

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create unified ProofAlphaCard component

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift`

**Why:** DepthCard, GlassCard, and SpotlightCard share ~80% of their code. 3D tilt uses `NSApp.windows.first` (window-level coords) so all cards tilt identically. SpotlightCard's spotlight stays fixed at center (0.5, 0.5). Merge into one component with `Emphasis` enum, fix tilt to use per-card GeometryReader coords.

- [ ] **Step 1: Add unified ProofAlphaCard at the top of ProofAlphaComponents.swift (after imports, before DepthCard)**

```swift
// MARK: - ProofAlphaCard — 统一卡片组件（合并 DepthCard + GlassCard + SpotlightCard）

struct ProofAlphaCard<Content: View>: View {
    enum Emphasis {
        case subtle    // 低透明度，无 glow，无 tilt — Dashboard/Trades
        case balanced  // 中透明度，hover accent 边框，聚光灯跟随，无 tilt — 策略/设置
        case bold      // 高透明度，accent 常驻边框，3D tilt + 聚光灯 — Landing/AI Studio
    }

    @Environment(PulseColors.self) private var colors
    var emphasis: Emphasis = .subtle
    var cardPadding: CGFloat = PulseSpacing.md
    let content: () -> Content

    @State private var isHovering = false
    @State private var rotateX: Double = 0
    @State private var rotateY: Double = 0
    @State private var hoverPoint: CGPoint = .zero
    @State private var viewSize: CGSize = .zero
    @State private var isPressed = false

    private let maxRotation: Double = 3.5

    var body: some View {
        content()
            .padding(cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .overlay(cardBorder)
            .overlay(topHighlightLine)
            .overlay(spotlightOverlay)
            .overlay(hoverBorderOverlay)
            .applyShadow(PulseShadow.card(colors))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? 0.05 : 0)
            .animation(PulseAnimation.easeOutFast, value: isPressed)
            .background(geometryReader)
            .rotation3DEffect(
                emphasis == .bold ? .degrees(rotateX) : .degrees(0),
                axis: (x: 1, y: 0, z: 0), perspective: 0.5
            )
            .rotation3DEffect(
                emphasis == .bold ? .degrees(rotateY) : .degrees(0),
                axis: (x: 0, y: 1, z: 0), perspective: 0.5
            )
            .animation(PulseAnimation.easeOutFast, value: isHovering)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    isHovering = true
                    hoverPoint = point
                    if emphasis == .bold {
                        let w = max(viewSize.width, 1)
                        let h = max(viewSize.height, 1)
                        let normalizedX = point.x / w - 0.5
                        let normalizedY = point.y / h - 0.5
                        rotateY = normalizedX * maxRotation * 2
                        rotateX = -normalizedY * maxRotation * 2
                    }
                case .ended:
                    isHovering = false
                    rotateX = 0
                    rotateY = 0
                }
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in }
            )
            ._onPress { pressed in
                withAnimation(PulseAnimation.easeOutFast) {
                    isPressed = pressed
                }
            }
    }

    // MARK: - 卡片背景

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .fill(emphasis == .subtle
                ? colors.cardBackground
                : colors.cardBackground.opacity(emphasis == .bold ? 1.0 : 1.0))
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(.ultraThinMaterial)
            )
    }

    // MARK: - 默认边框

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .stroke(
                emphasis == .bold
                    ? PulseGlass.accentBorder
                    : Color.white.opacity(0.05),
                lineWidth: 1
            )
    }

    // MARK: - 顶部高光线

    @ViewBuilder
    private var topHighlightLine: some View {
        if emphasis != .subtle {
            VStack {
                LinearGradient(
                    colors: [.clear, PulseColors.accent.opacity(emphasis == .bold ? 0.35 : 0.2), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
        }
    }

    // MARK: - 聚光灯叠加层

    private var spotlightOverlay: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .fill(
                RadialGradient(
                    colors: [
                        PulseColors.accent.opacity(emphasis == .bold ? 0.10 : 0.06),
                        .clear
                    ],
                    center: emphasis != .subtle
                        ? UnitPoint(
                            x: viewSize.width > 0 ? hoverPoint.x / viewSize.width : 0.5,
                            y: viewSize.height > 0 ? hoverPoint.y / viewSize.height : 0.5
                          )
                        : UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: - Hover 边框 glow

    private var hoverBorderOverlay: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .stroke(
                isHovering && emphasis != .subtle
                    ? PulseGlass.accentBorderHover
                    : Color.clear,
                lineWidth: 1
            )
    }

    // MARK: - GeometryReader（per-card 坐标）

    private var geometryReader: some View {
        GeometryReader { geo in
            Color.clear.onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, newSize in viewSize = newSize }
        }
    }
}

// MARK: - _onPress helper (macOS 14+ compatible press detection)

extension View {
    func _onPress(onChanged: @escaping (Bool) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onChanged(true) }
                .onEnded { _ in onChanged(false) }
        )
    }
}
```

Note: The `_onPress` helper uses `DragGesture(minimumDistance: 0)` as a private implementation detail of the card component only. The shared `PressEffectModifier` fix is handled in Task 3 separately.

- [ ] **Step 2: Mark old components as deprecated**

Add a comment above each of `DepthCard`, `GlassCard`, `SpotlightCard`:

```swift
// DEPRECATED: Use ProofAlphaCard(emphasis:) instead. Kept for source compatibility
// during migration; remove after Batch C completes.
```

- [ ] **Step 3: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Views/Shared/ProofAlphaComponents.swift
git commit -m "$(cat <<'EOF'
feat(design): add unified ProofAlphaCard with emphasis levels

Merge DepthCard, GlassCard, SpotlightCard into single component. Fix 3D
tilt to use per-card GeometryReader coordinates. Spotlight tracks cursor.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Fix PressEffectModifier to not conflict with ScrollView

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/ViewModifiers.swift:92-103`

**Why:** `PressEffectModifier` uses `DragGesture(minimumDistance: 0)` which hijacks scroll gestures when applied to rows inside a ScrollView. Replace with a combination approach: use `TapGesture` (doesn't conflict with scroll) for the visual feedback.

- [ ] **Step 1: Replace PressEffectModifier**

In `ViewModifiers.swift`, replace the existing `PressEffectModifier` (lines 91-103):

```swift
// MARK: - 按压反馈 (pressesBegan-compatible via simultaneousGesture)
struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false
    var scale: CGFloat = 0.97

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .brightness(isPressed ? 0.04 : 0)
            .animation(PulseAnimation.easeOutFast, value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(PulseAnimation.easeOutFast) {
                        isPressed = pressing
                    }
                },
                perform: {}
            )
    }
}
```

This uses `onLongPressGesture(minimumDuration: 0)` which provides pressing state without conflicting with ScrollView scrolling — the framework cancels the "press" when a scroll begins.

- [ ] **Step 2: Update pressEffect extension default**

In `ViewModifiers.swift`, update the extension:

```swift
func pressEffect(scale: CGFloat = 0.97) -> some View {
    modifier(PressEffectModifier(scale: scale))
}
```

- [ ] **Step 3: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/DesignSystem/ViewModifiers.swift
git commit -m "$(cat <<'EOF'
fix(design): fix PressEffectModifier to not conflict with ScrollView

Replace DragGesture(minimumDistance: 0) with onLongPressGesture(minimumDuration: 0)
which natively cancels when scrolling begins.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Update HoverEffectModifier default scale

**Files:**
- Modify: `macos-app/PulseDesk/DesignSystem/ViewModifiers.swift:77`

**Why:** Current default scale of 1.01 is too subtle to notice on fast mouse movements. 1.03 provides visible but not jarring feedback.

- [ ] **Step 1: Change default scale value**

In `ViewModifiers.swift`, line 77:

```swift
// Change:
// var scale: CGFloat = 1.01
// To:
var scale: CGFloat = 1.03
```

Also update the extension default at line ~125:
```swift
// Change:
// func hoverEffect(scale: CGFloat = 1.01) -> some View {
// To:
func hoverEffect(scale: CGFloat = 1.03) -> some View {
```

- [ ] **Step 2: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/DesignSystem/ViewModifiers.swift
git commit -m "$(cat <<'EOF'
tweak(design): increase HoverEffectModifier default scale 1.01 → 1.03

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Redesign LoadingView with type-based skeletons

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/LoadingView.swift`

**Why:** Current LoadingView only renders 3 uniform rectangles. Different pages need different skeleton shapes (dashboard grid, list rows, detail page, inline progress bar). No shimmer phase staggering.

- [ ] **Step 1: Rewrite LoadingView.swift**

```swift
// LoadingView.swift — 骨架屏加载视图（多类型）

import SwiftUI

struct LoadingView: View {
    enum LoadingType {
        case dashboard  // KPI row + chart + two-column
        case listRow    // Single list row skeleton
        case detail     // Detail page skeleton
        case grid       // Grid skeleton
        case inline     // Thin progress bar for polling refreshes
    }

    @Environment(PulseColors.self) private var colors
    var type: LoadingType = .dashboard

    var body: some View {
        switch type {
        case .dashboard: dashboardSkeleton
        case .listRow:   listRowSkeleton
        case .detail:    detailSkeleton
        case .grid:      gridSkeleton
        case .inline:    inlineProgress
        }
    }

    // MARK: - Dashboard skeleton (4 KPI cards + chart + two-column)

    private var dashboardSkeleton: some View {
        VStack(spacing: PulseSpacing.md) {
            HStack(spacing: PulseSpacing.xs) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface)
                        .frame(height: 88)
                        .shimmerWithDelay(phase: Double(i) * 0.15)
                }
            }
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.surface)
                .frame(height: 160)
                .shimmerWithDelay(phase: 0)
            HStack(alignment: .top, spacing: PulseSpacing.md) {
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface)
                    .frame(height: 200)
                    .shimmerWithDelay(phase: 0.1)
                VStack(spacing: PulseSpacing.md) {
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 100)
                        .shimmerWithDelay(phase: 0.2)
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(colors.surface).frame(height: 100)
                        .shimmerWithDelay(phase: 0.3)
                }
                .frame(width: 280)
            }
        }
    }

    // MARK: - List row skeleton (for table-like views)

    private var listRowSkeleton: some View {
        HStack(spacing: PulseSpacing.sm) {
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(width: 24, height: 24)
                .shimmerWithDelay(phase: 0)
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(colors.surface).frame(width: 120, height: 14)
                    .shimmerWithDelay(phase: 0.05)
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(colors.surface).frame(width: 80, height: 10)
                    .shimmerWithDelay(phase: 0.1)
            }
            Spacer()
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(width: 60, height: 14)
                .shimmerWithDelay(phase: 0.15)
        }
        .padding(.vertical, PulseSpacing.sm)
        .padding(.horizontal, PulseSpacing.md)
    }

    // MARK: - Detail page skeleton

    private var detailSkeleton: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(width: 200, height: 24)
                .shimmerWithDelay(phase: 0)
            RoundedRectangle(cornerRadius: PulseRadii.xs)
                .fill(colors.surface).frame(height: 120)
                .shimmerWithDelay(phase: 0.1)
            VStack(spacing: PulseSpacing.sm) {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface).frame(width: 100, height: 14)
                            .shimmerWithDelay(phase: Double(i) * 0.1)
                        Spacer()
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(colors.surface).frame(width: 140, height: 14)
                            .shimmerWithDelay(phase: Double(i) * 0.1 + 0.05)
                    }
                }
            }
        }
    }

    // MARK: - Grid skeleton

    private var gridSkeleton: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: PulseSpacing.sm)], spacing: PulseSpacing.sm) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.surface).frame(height: 100)
                    .shimmerWithDelay(phase: Double(i) * 0.1)
            }
        }
    }

    // MARK: - Inline progress bar (polling refresh)

    private var inlineProgress: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(PulseColors.accent.opacity(0.3))
                .frame(width: geo.size.width * 0.3, height: 2)
                .offset(x: 0)
        }
        .frame(height: 2)
    }
}

// MARK: - Staggered shimmer helper

extension View {
    func shimmerWithDelay(phase: Double) -> some View {
        self.modifier(StaggeredShimmerModifier(phase: phase))
    }
}

struct StaggeredShimmerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    let phase: Double
    @State private var animPhase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: animPhase - 0.3),
                            .init(color: colors.surfaceHover, location: animPhase),
                            .init(color: .clear, location: animPhase + 0.3),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + geometry.size.width * 2 * animPhase)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                    .delay(phase)
                ) {
                    animPhase = 1.0
                }
            }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Shared/LoadingView.swift
git commit -m "$(cat <<'EOF'
feat(design): add type-based skeleton variants to LoadingView

Support dashboard, listRow, detail, grid, and inline polling types with
staggered shimmer phase offsets for organic loading feel.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Refine EmptyStateView

**Files:**
- Modify: `macos-app/PulseDesk/Views/Shared/EmptyStateView.swift`

**Why:** Min height 80pt is too cramped. Float animation uses mechanical `easeInOut`. No entrance animation. No secondary action support. Icon weight `.light` at `opacity(0.5)` too faint.

- [ ] **Step 1: Rewrite EmptyStateView.swift**

```swift
// EmptyStateView.swift — 空状态视图
// 图标 + 标题 + 描述 + 可选操作按钮，带浮动和入场动画

import SwiftUI

struct EmptyStateView: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let title: String
    let description: String
    var primaryAction: (title: String, action: () -> Void)?
    var secondaryAction: (title: String, action: () -> Void)?

    @State private var floatOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(PulseColors.accent.opacity(0.6))
                .offset(y: floatOffset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(
                            .spring(response: 2.0, dampingFraction: 0.3)
                            .repeatForever(autoreverses: true)
                        ) {
                            floatOffset = -6
                        }
                    }
                }

            Text(title)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)

            Text(description)
                .font(PulseFonts.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: PulseSpacing.sm) {
                if let primaryAction {
                    ProofAlphaButton(title: primaryAction.title, action: primaryAction.action)
                }
                if let secondaryAction {
                    ProofAlphaButton(title: secondaryAction.title, action: secondaryAction.action, style: .ghost)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(PulseSpacing.xl)
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(
                PulseAnimation.springDefault.delay(0.05)
            ) {
                appeared = true
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: Build succeeds (no callers broken — old `actionTitle`/`action` params removed, but check for compile errors and fix callers if needed)

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Shared/EmptyStateView.swift
git commit -m "$(cat <<'EOF'
feat(design): refine EmptyStateView with spring animation and secondary action

- Min height 80pt → 120pt
- Float: easeInOut → spring(response: 2.0, dampingFraction: 0.3)
- Icon: .light → .regular, opacity 0.5 → 0.6
- Add secondaryAction parameter for ghost-style second CTA
- Add entrance animation (.scale + .opacity)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Fix LandingView — replace inline PulseRing + hardcoded font

**Files:**
- Modify: `macos-app/PulseDesk/Views/Landing/LandingView.swift`

**Why:** LandingView duplicates PulseRing code inline (3 circles in a ForEach) instead of using the shared `PulseRing()` component from AnimatedEffects.swift. Title uses hardcoded `.font(.system(size: 48, ...))` instead of PulseFonts token.

- [ ] **Step 1: Replace inline PulseRing code with shared component**

In `LandingView.swift`, find the ZStack containing the `ForEach(0..<3)` with `Circle().stroke(...)` and the `RadialGradient` background. Replace with:

```swift
// Replace this entire block (the ZStack inside VStack with RadialGradient + ForEach circles + Image):
/*
                    ZStack {
                        RadialGradient(
                            colors: [PulseColors.accent.opacity(0.15), .clear],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                        .frame(width: 240, height: 240).blur(radius: 40)

                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(PulseColors.accent.opacity(0.15), lineWidth: 1)
                                .frame(width: 72, height: 72)
                                .scaleEffect(pulseScale)
                                .opacity(pulseScale > 1.5 ? 0 : 0.5)
                                .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(Double(index) * 0.6), value: pulseScale)
                        }

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(PulseColors.accent)
                            .shadow(color: PulseColors.accent.opacity(0.5), radius: 15)
                            .shadow(color: PulseColors.accent.opacity(0.2), radius: 30)
                    }
                    .onAppear { pulseScale = 2.5 }
*/

// With:
                    ZStack {
                        RadialGradient(
                            colors: [PulseColors.accent.opacity(0.15), .clear],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                        .frame(width: 240, height: 240).blur(radius: 40)

                        PulseRing(color: PulseColors.accent, size: 72)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(PulseColors.accent)
                            .shadow(color: PulseColors.accent.opacity(0.5), radius: 15)
                            .shadow(color: PulseColors.accent.opacity(0.2), radius: 30)
                    }
```

- [ ] **Step 2: Replace hardcoded title font with PulseFonts token**

Find the `BlurTextReveal` line with `.font(.system(size: 48, weight: .bold, design: .rounded))` and replace:

```swift
// Replace:
// BlurTextReveal(...).font(.system(size: 48, weight: .bold, design: .rounded))

// With:
BlurTextReveal(text: "PulseDesk", delay: 0.2, duration: 0.8)
    .font(.system(size: 48, weight: .bold, design: .rounded)) // kept as-is — displayTitle is 28pt, Landing needs dramatic scale
```

Note: The landing title at 48pt is intentionally larger than `PulseFonts.displayTitle` (28pt). This is acceptable — it's a hero element, not a reusable heading. Keep the font but remove the `pulseScale` @State since it's no longer used.

- [ ] **Step 3: Remove unused `pulseScale` state**

Remove: `@State private var pulseScale: CGFloat = 1.0`

- [ ] **Step 4: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Views/Landing/LandingView.swift
git commit -m "$(cat <<'EOF'
refactor(landing): use shared PulseRing component, remove inline duplicate

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Delete dead ToolbarView.swift

**Files:**
- Delete: `macos-app/PulseDesk/Views/AppShell/ToolbarView.swift`

**Why:** `ToolbarView` is never used in the app shell layout. All toolbar logic lives in `AppShellView.ConsoleToolbar`. This file is dead code that will diverge over time.

- [ ] **Step 1: Verify no references before deleting**

Run: `grep -r "ToolbarView" macos-app/PulseDesk/ --include="*.swift" -l`
Expected: Only `ToolbarView.swift` itself. If any other file references it, note it and skip deletion.

- [ ] **Step 2: Delete the file**

Run: `rm macos-app/PulseDesk/Views/AppShell/ToolbarView.swift`

- [ ] **Step 3: Build to verify**

Run: `cd macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds (BUILD SUCCESS)

- [ ] **Step 4: Commit**

```bash
git rm macos-app/PulseDesk/Views/AppShell/ToolbarView.swift
git commit -m "$(cat <<'EOF'
chore: remove dead ToolbarView.swift (duplicate of AppShell.ConsoleToolbar)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Build full verification

- [ ] **Step 1: Clean build**

Run: `cd macos-app && swift build 2>&1`
Expected: `Build complete!` with no errors or warnings

- [ ] **Step 2: Run backend tests (regression check)**

Run: `cd backend && python3 -m pytest tests/ -q 2>&1`
Expected: All tests pass

- [ ] **Step 3: Commit any remaining changes**

```bash
git status
```

If clean, done. If there are any modified files from fixing callers, commit them.

---

### Task 10: Update callers to use new API (migration bridge)

**Files:**
- Scan and update: all files using `GlassCard(`, `DepthCard(`, `SpotlightCard(`

**Why:** Existing callers of the old card APIs should gradually migrate to `ProofAlphaCard(emphasis:)`. For Batch A, we only need to verify backward compat (old components still exist as deprecated). Full migration happens in Batch B/C/D.

- [ ] **Step 1: Count current usage of old card types**

Run:
```bash
grep -r "GlassCard(" macos-app/PulseDesk/ --include="*.swift" -c | grep -v ":0$" | wc -l
grep -r "DepthCard(" macos-app/PulseDesk/ --include="*.swift" -c | grep -v ":0$" | wc -l
grep -r "SpotlightCard(" macos-app/PulseDesk/ --include="*.swift" -c | grep -v ":0$" | wc -l
```

- [ ] **Step 2: Verify build is green (no forced migration in Batch A)**

Run: `cd macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds (old APIs still available as deprecated)

- [ ] **Step 3: Commit**

No code changes needed in this task — verification only.

---

## Summary

| Task | Files Changed | Risk |
|------|--------------|------|
| 1. loss theme fix | DesignTokens.swift | Low |
| 2. Unified ProofAlphaCard | ProofAlphaComponents.swift | Medium — keep old APIs as deprecated |
| 3. PressEffectModifier fix | ViewModifiers.swift | Low |
| 4. HoverEffect scale | ViewModifiers.swift | Low |
| 5. LoadingView types | LoadingView.swift | Low |
| 6. EmptyStateView refine | EmptyStateView.swift | Low |
| 7. LandingView fixes | LandingView.swift | Low |
| 8. Delete ToolbarView | ToolbarView.swift | Low (verify no refs) |
| 9. Full build verify | — | — |
| 10. Caller audit | — | Verification only |

After Batch A completes, all views can begin using:
- `ProofAlphaCard(emphasis:)` for new card instances
- `LoadingView(type:)` for typed skeletons
- `EmptyStateView` with secondary actions
- Fixed `pressEffect()` that works in ScrollViews
- Theme-responsive `colors.loss`
