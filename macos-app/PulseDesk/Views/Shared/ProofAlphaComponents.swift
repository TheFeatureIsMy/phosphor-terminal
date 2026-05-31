// ProofAlphaComponents.swift — ProofAlpha 核心交互组件
// DepthCard (3D倾斜+聚光灯), SpotlightCard (光标跟随), TerminalLabel, BadgeDot

import SwiftUI

// MARK: - ProofAlphaCard — 统一卡片组件

struct ProofAlphaCard<Content: View>: View {
    enum Emphasis {
        case subtle    // Dashboard/Trades — 低透明度，无发光，无倾斜
        case balanced  // Strategies/Settings — 中等，悬停强调边框，聚光灯，无倾斜
        case bold      // Landing/AI Studio — 高透明度，强调边框，3D倾斜 + 聚光灯
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
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(PulseAnimation.easeOutFast) { isPressed = pressing }
                },
                perform: {}
            )
    }

    // Card background
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .fill(colors.cardBackground)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(.ultraThinMaterial)
            )
    }

    // Default border (subtle gets subtle white, bold gets accent)
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .stroke(
                emphasis == .bold
                    ? PulseGlass.accentBorder
                    : Color.white.opacity(0.05),
                lineWidth: 1
            )
    }

    // Top highlight line (balanced and bold only)
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

    // Spotlight overlay (balanced and bold only, follows cursor)
    private var spotlightOverlay: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .fill(
                RadialGradient(
                    colors: [
                        PulseColors.accent.opacity(emphasis == .bold ? 0.10 : 0.06),
                        .clear
                    ],
                    center: emphasis != .subtle && viewSize.width > 0
                        ? UnitPoint(
                            x: hoverPoint.x / viewSize.width,
                            y: hoverPoint.y / viewSize.height
                          )
                        : UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .opacity(isHovering && emphasis != .subtle ? 1 : 0)
            .allowsHitTesting(false)
    }

    // Hover border glow (balanced and bold only)
    private var hoverBorderOverlay: some View {
        RoundedRectangle(cornerRadius: PulseRadii.card)
            .stroke(
                isHovering && emphasis != .subtle
                    ? PulseGlass.accentBorderHover
                    : Color.clear,
                lineWidth: 1
            )
    }

    // GeometryReader for per-card coordinates
    private var geometryReader: some View {
        GeometryReader { geo in
            Color.clear.onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, newSize in viewSize = newSize }
        }
    }
}

// DEPRECATED: Use ProofAlphaCard(emphasis:) instead.
// Kept for source compatibility during migration; remove after Batch C.
// MARK: - DepthCard — 3D 倾斜 + 聚光灯效果
struct DepthCard<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    var maxRotation: Double = 3.5
    var spotlightColor: Color = PulseColors.accent.opacity(0.08)
    var cardPadding: CGFloat = PulseSpacing.md
    let content: () -> Content

    @State private var rotateX: Double = 0
    @State private var rotateY: Double = 0
    @State private var spotlightX: CGFloat = 0
    @State private var spotlightY: CGFloat = 0
    @State private var spotlightOpacity: Double = 0
    @State private var isHovering = false

    var body: some View {
        content()
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .applyShadow(PulseShadow.card(colors))
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
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .fill(
                            RadialGradient(
                                colors: [spotlightColor, .clear],
                                center: UnitPoint(x: 0.5, y: 0.5),
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .opacity(spotlightOpacity)
                        .allowsHitTesting(false)
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

// DEPRECATED: Use ProofAlphaCard(emphasis:) instead.
// Kept for source compatibility during migration; remove after Batch C.
// MARK: - SpotlightCard — 光标跟随聚光灯 (无 3D 倾斜)
struct SpotlightCard<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    var spotlightColor: Color = PulseColors.accent.opacity(0.10)
    var cardPadding: CGFloat = PulseSpacing.md
    let content: () -> Content

    @State private var position: CGPoint = .zero
    @State private var isHovered = false

    var body: some View {
        content()
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .applyShadow(PulseShadow.card(colors))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(
                        RadialGradient(
                            colors: [spotlightColor, .clear],
                            center: UnitPoint(x: 0.5, y: 0.5),
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: isHovered)
                    .allowsHitTesting(false)
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

// DEPRECATED: Use ProofAlphaCard(emphasis:) instead.
// Kept for source compatibility during migration; remove after Batch C.
// MARK: - GlassCard — 统一卡片样式（3D 倾斜 + 聚光灯 + 顶部高光线）
struct GlassCard<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    var cardPadding: CGFloat = PulseSpacing.md
    var enable3D: Bool = true
    let content: () -> Content

    @State private var isHovering = false
    @State private var rotateX: Double = 0
    @State private var rotateY: Double = 0
    @State private var hoverPoint: CGPoint = .zero
    @State private var viewSize: CGSize = .zero

    private let maxRotation: Double = 3.5

    var body: some View {
        content()
            .padding(cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.card)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .overlay(
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
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
            )
            .overlay(
                // 鼠标跟随聚光灯
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(
                        RadialGradient(
                            colors: [PulseColors.accent.opacity(0.08), .clear],
                            center: UnitPoint(
                                x: hoverPoint.x / max(viewSize.width, 1),
                                y: hoverPoint.y / max(viewSize.height, 1)
                            ),
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(
                        isHovering ? PulseColors.accent.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .applyShadow(PulseShadow.card(colors))
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { viewSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in viewSize = newSize }
                }
            )
            .rotation3DEffect(enable3D ? .degrees(rotateX) : .degrees(0), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(enable3D ? .degrees(rotateY) : .degrees(0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .animation(PulseAnimation.easeOutFast, value: isHovering)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    isHovering = true
                    hoverPoint = point
                    if enable3D, let window = NSApp.windows.first {
                        let wSize = window.frame.size
                        let normalizedX = point.x / max(wSize.width, 1) - 0.5
                        let normalizedY = point.y / max(wSize.height, 1) - 0.5
                        rotateY = normalizedX * maxRotation * 2
                        rotateX = -normalizedY * maxRotation * 2
                    }
                case .ended:
                    isHovering = false
                    rotateX = 0
                    rotateY = 0
                }
            }
    }
}

// MARK: - TerminalLabel — "// LABEL" 终端风格标签
struct TerminalLabel: View {
    @Environment(PulseColors.self) private var colors
    let text: String

    var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Text("//")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(PulseColors.accent)

            Text(text)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)
        }
    }
}

// MARK: - BadgeDot — 圆点 + 标签徽章
struct BadgeDot: View {
    let color: Color
    let label: String
    var size: BadgeDotSize = .small

    enum BadgeDotSize {
        case small, medium

        var font: Font {
            switch self {
            case .small: return PulseFonts.micro
            case .medium: return PulseFonts.captionMedium
            }
        }

        var padding: (h: CGFloat, v: CGFloat) {
            switch self {
            case .small: return (6, 2)
            case .medium: return (8, 3)
            }
        }

        var dotSize: CGFloat {
            switch self {
            case .small: return 5
            case .medium: return 6
            }
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: size.dotSize, height: size.dotSize)

            Text(label)
                .font(size.font)
                .foregroundStyle(color)
                .textCase(.uppercase)
        }
        .padding(.horizontal, size.padding.h)
        .padding(.vertical, size.padding.v)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.badge)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - StatusDot — LED 脉冲状态指示器
struct StatusDot: View {
    let status: StatusType

    enum StatusType {
        case online, offline, loading

        var color: Color {
            switch self {
            case .online: return PulseColors.statusActive
            case .offline: return PulseColors.statusError
            case .loading: return PulseColors.cyan
            }
        }
    }

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // 外圈脉冲
            Circle()
                .fill(status.color.opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.8 : 1.0)
                .opacity(isPulsing ? 0 : 0.75)
                .animation(
                    .easeOut(duration: 1.2)
                    .repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // 内圈实心
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .shadow(color: status.color.opacity(0.5), radius: 4)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - GlowText — 霓虹绿发光文字
struct GlowText: View {
    let text: String
    var font: Font = PulseFonts.displayHeading

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(PulseColors.accent)
            .shadow(color: PulseColors.accent.opacity(0.5), radius: 10)
            .shadow(color: PulseColors.accent.opacity(0.25), radius: 20)
    }
}

// MARK: - GradientText — 渐变文字 (绿→青)
struct GradientText: View {
    let text: String
    var font: Font = PulseFonts.displayHeading

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: [PulseColors.accent, PulseColors.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - ProofAlphaButton — 霓虹绿按钮 (2px 圆角, 大写)
struct ProofAlphaButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary
    @Environment(PulseColors.self) private var colors

    enum ButtonStyle {
        case primary, ghost
    }

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PulseFonts.monoLabel)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.button))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .stroke(borderColor, lineWidth: style == .ghost ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .shadow(
            color: isHovered && style == .primary
                ? PulseColors.accent.opacity(0.2) : .clear,
            radius: 10
        )
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return colors.background
        case .ghost: return isHovered ? PulseColors.accent : colors.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return isHovered ? PulseColors.accentLight : PulseColors.accent
        case .ghost: return isHovered ? PulseColors.accent.opacity(0.04) : .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .ghost: return isHovered ? PulseColors.accent : colors.border
        }
    }
}
