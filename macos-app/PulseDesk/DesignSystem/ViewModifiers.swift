// ViewModifiers.swift — ProofAlpha 可复用视图修饰器
// 玻璃态卡片、悬停/按压反馈、骨架屏、交错动画

import SwiftUI

// MARK: - 卡片样式 (ProofAlpha 玻璃态)
struct CardModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    var padding: CGFloat = PulseSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
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
    }
}

// MARK: - 玻璃效果（侧边栏/顶栏面板用 — ProofAlpha 玻璃态）
struct GlassModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .glassEffect()
            .overlay(
                Rectangle()
                    .fill(PulseGlass.surfaceTint(colors))
                    .allowsHitTesting(false)
            )
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - 条件玻璃效果（选中态专用）
struct ConditionalGlassModifier: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        if isActive {
            if cornerRadius > 0 {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular)
            }
        } else {
            content
        }
    }
}

// MARK: - 交互式玻璃效果（可点击控件用）
struct InteractiveGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive())
    }
}

// MARK: - 玻璃 ID（用于形态变换过渡）
struct GlassIDModifier: ViewModifier {
    let id: String

    func body(content: Content) -> some View {
        content
            .glassEffectID(id)
    }
}

// MARK: - 悬停玻璃效果（侧边栏/设置按钮专用 — Liquid Glass + accent 描边）
struct HoverGlassModifier: ViewModifier {
    @State private var isHovering = false
    var cornerRadius: CGFloat = PulseRadii.md

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive())
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
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

// MARK: - 悬停效果
struct HoverEffectModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false
    var scale: CGFloat = 1.03

    func body(content: Content) -> some View {
        let elevated = PulseShadow.elevated(colors)
        return content
            .scaleEffect(isHovering ? scale : 1.0)
            .shadow(color: isHovering ? elevated.color : .clear,
                    radius: isHovering ? elevated.radius : 0,
                    y: isHovering ? elevated.y : 0)
            .onHover { hovering in
                withAnimation(PulseAnimation.easeOutFast) {
                    isHovering = hovering
                }
            }
    }
}

// MARK: - 按压反馈
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

// MARK: - 骨架屏 Shimmer
struct ShimmerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
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
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

// MARK: - 交错出场动画
struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(
                    PulseAnimation.springDefault
                        .delay(baseDelay + Double(index) * PulseAnimation.staggerDelay)
                ) {
                    appeared = true
                }
            }
    }
}

// MARK: - 终端标签样式
struct TerminalLabelModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .font(PulseFonts.monoLabel)
            .foregroundColor(colors.textMuted)
            .textCase(.uppercase)
            .tracking(1.5)
    }
}

// MARK: - View 扩展
extension View {
    func cardStyle(padding: CGFloat = PulseSpacing.md) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func glassStyle() -> some View {
        modifier(GlassModifier())
    }

    func hoverEffect(scale: CGFloat = 1.03) -> some View {
        modifier(HoverEffectModifier(scale: scale))
    }

    func pressEffect(scale: CGFloat = 0.97) -> some View {
        modifier(PressEffectModifier(scale: scale))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func staggeredAppearance(index: Int, baseDelay: Double = 0.05) -> some View {
        modifier(StaggeredAppearanceModifier(index: index, baseDelay: baseDelay))
    }

    func terminalLabel() -> some View {
        modifier(TerminalLabelModifier())
    }

    func interactiveGlassStyle() -> some View {
        modifier(InteractiveGlassModifier())
    }

    func hoverGlassStyle(cornerRadius: CGFloat = PulseRadii.md) -> some View {
        modifier(HoverGlassModifier(cornerRadius: cornerRadius))
    }

    func glassEffectID(_ id: String) -> some View {
        modifier(GlassIDModifier(id: id))
    }
}
