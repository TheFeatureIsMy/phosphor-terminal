// ViewModifiers.swift — VOLT 可复用视图修饰器
// 炭卡 + 硬边框 + 电光强调;slam 入场;mono 终端标签

import SwiftUI

// MARK: - 卡片样式 (统一 = dashboard ProtocolCard 语言:1pt 边框 + 卡片阴影 + hover 浮起)
struct CardModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    var padding: CGFloat = PulseSpacing.md
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .voltCardSurface()
    }
}

// MARK: - 统一卡片表面 (不含 padding,供已自管内边距的内联卡迁移)
// 与 dashboard ProtocolCard 同款:cardBackground + 1pt border + 卡片阴影;
// hover:边框加亮 + elevated 阴影 + 浮起 2pt。voltBorder = 电光描边变体(Verdict 卡等)。
struct VoltCardSurfaceModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    var voltBorder: Bool = false
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .fill(colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.card)
                    .stroke(voltBorder ? PulseColors.accent.opacity(0.4) : (isHovering ? colors.borderHover : colors.border),
                            lineWidth: 1)
            )
            .shadow(color: voltBorder ? PulseColors.accent.opacity(isHovering ? 0.12 : 0.06) : .clear,
                    radius: voltBorder ? 32 : 0, y: 0)
            .applyShadow(isHovering ? PulseShadow.elevated(colors) : PulseShadow.card(colors))
            .offset(y: isHovering ? -2 : 0)
            .animation(PulseAnimation.hoverLift, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

// MARK: - 面板样式（侧边栏/顶栏 — Protocol 白底,不再玻璃拟态）
struct GlassModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .background(colors.cardBackground)
            .overlay(
                Rectangle()
                    .stroke(colors.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - 条件强调（选中态专用 — Protocol accent-soft tint）
struct ConditionalGlassModifier: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 0
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        if isActive {
            content.background(
                RoundedRectangle(cornerRadius: cornerRadius > 0 ? cornerRadius : PulseRadii.button)
                    .fill(PulseColors.accentSoft)
            )
        } else {
            content
        }
    }
}

// MARK: - 交互式表面（可点击控件用 — Protocol 白底）
struct InteractiveGlassModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    func body(content: Content) -> some View {
        content
            .background(colors.cardBackground)
    }
}

// MARK: - 玻璃 ID（用于形态变换过渡 — Protocol 下为空操作）
struct GlassIDModifier: ViewModifier {
    let id: String

    func body(content: Content) -> some View {
        content
    }
}

// MARK: - 悬停效果（侧边栏/设置按钮 — Protocol accent-soft hover）
struct HoverGlassModifier: ViewModifier {
    @State private var isHovering = false
    var cornerRadius: CGFloat = PulseRadii.md
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovering ? colors.surfaceHover : Color.clear)
            )
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

// MARK: - 骨架屏 Shimmer (TimelineView 驱动;reduced-motion 时静止)
struct ShimmerModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // 降级:静态浅色覆盖,不滚动
            content.overlay(colors.surface.opacity(0.6))
        } else {
            content
                .overlay(
                    GeometryReader { geometry in
                        TimelineView(.animation) { timeline in
                            let phase = timeline.date.timeIntervalSince1970
                                .truncatingRemainder(dividingBy: 1.5) / 1.5
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, phase - 0.3)),
                                    .init(color: colors.surfaceHover, location: phase),
                                    .init(color: .clear, location: min(1, phase + 0.3)),
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
}

// MARK: - 交错出场动画(支持 reduced-motion 降级)
struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared && !reduceMotion ? 0 : 8)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(
                        PulseAnimation.slam
                            .delay(baseDelay + Double(index) * PulseAnimation.staggerDelay)
                    ) {
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - 终端标签样式
struct TerminalLabelModifier: ViewModifier {
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        content
            .font(PulseFonts.mono(11, .semibold))
            .foregroundColor(colors.textSecondary)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - View 扩展
extension View {
    func cardStyle(padding: CGFloat = PulseSpacing.md) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// 统一卡片表面(dashboard ProtocolCard 语言),不含 padding
    func voltCardSurface(voltBorder: Bool = false) -> some View {
        modifier(VoltCardSurfaceModifier(voltBorder: voltBorder))
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
