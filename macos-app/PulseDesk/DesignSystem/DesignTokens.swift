// DesignTokens.swift — ProofAlpha 设计系统
// 双主题支持：暗黑赛博朋克 + 明亮科技风

import SwiftUI

// MARK: - 主题管理器
@Observable
class ThemeManager {
    enum Theme: String, CaseIterable {
        case dark, light
        var label: String { self == .dark ? "暗黑" : "明亮" }
        var icon: String { self == .dark ? "moon.fill" : "sun.max.fill" }
    }

    var current: Theme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "theme") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "theme") ?? "dark"
        self.current = Theme(rawValue: saved) ?? .dark
    }

    func toggle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            current = current == .dark ? .light : .dark
        }
    }

    var isDark: Bool { current == .dark }
}

// MARK: - 颜色系统（双主题）
// @Observable 确保主题切换时 SwiftUI 自动重渲染
@Observable
class PulseColors {
    let themeManager: ThemeManager

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    private var isDark: Bool { themeManager.current == .dark }

    // 主题色 — 柔和霓虹绿（降低饱和度，提升可读性）
    static let accent = Color(red: 0.0, green: 0.85, blue: 0.55) // 柔和绿
    static let accentLight = Color(red: 0.15, green: 0.95, blue: 0.65)
    static let accentDim = Color(red: 0.0, green: 0.85, blue: 0.55).opacity(0.10)

    // 盈亏色
    var profit: Color {
        isDark
            ? Color(red: 0.0, green: 0.75, blue: 0.5)   // 暗黑模式：柔和绿
            : Color(red: 0.0, green: 0.6, blue: 0.4)     // 明亮模式：更暗的绿
    }

    var loss: Color {
        isDark
            ? Color(red: 1.0, green: 0.231, blue: 0.231)  // #FF3B3B — dark
            : Color(red: 0.85, green: 0.15, blue: 0.15)    // dimmer red for light theme
    }
    static let loss = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B

    // 背景色
    var background: Color {
        isDark
            ? Color(red: 0.039, green: 0.039, blue: 0.043)  // #0A0A0A
            : Color(red: 0.96, green: 0.965, blue: 0.975)    // 浅灰蓝 #F5F6F9
    }

    // 玻璃态卡片底色
    var cardBackground: Color {
        isDark
            ? Color(red: 0.094, green: 0.094, blue: 0.106).opacity(0.55)
            : Color.white.opacity(0.65)
    }

    // 表面色
    var surface: Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }
    var surfaceElevated: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }
    var surfaceHover: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    var surfaceActive: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    // 文字色
    var textPrimary: Color {
        isDark
            ? Color(red: 0.878, green: 0.878, blue: 0.878)  // #E0E0E0
            : Color(red: 0.13, green: 0.13, blue: 0.15)      // #212126
    }
    var textSecondary: Color {
        isDark
            ? Color(red: 0.533, green: 0.533, blue: 0.533)  // #888888
            : Color(red: 0.4, green: 0.4, blue: 0.45)        // #666673
    }
    var textMuted: Color {
        isDark
            ? Color(red: 0.333, green: 0.333, blue: 0.333)  // #555555
            : Color(red: 0.6, green: 0.6, blue: 0.65)        // #9999A6
    }

    // 描边色
    var border: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    var borderHover: Color {
        isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.14)
    }
    static let borderAccent = Color(red: 0.0, green: 1.0, blue: 0.616).opacity(0.25)

    // 语义色（双主题通用）
    static let warning = Color(red: 1.0, green: 0.722, blue: 0.0) // #FFB800
    static let danger = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B
    static let info = Color(red: 0.0, green: 0.761, blue: 1.0) // #00C2FF
    static let success = Color(red: 0.0, green: 0.85, blue: 0.55)

    // 状态色
    static let statusActive = Color(red: 0.0, green: 0.85, blue: 0.55)
    static let statusPaused = Color(red: 1.0, green: 0.722, blue: 0.0) // #FFB800
    var statusDraft: Color {
        isDark
            ? Color(red: 0.333, green: 0.333, blue: 0.333)
            : Color(red: 0.6, green: 0.6, blue: 0.65)
    }
    static let statusError = Color(red: 1.0, green: 0.231, blue: 0.231) // #FF3B3B

    // 特殊色（双主题通用）
    static let purple = Color(red: 0.659, green: 0.333, blue: 0.969) // #A855F7
    static let cyan = Color(red: 0.0, green: 0.761, blue: 1.0) // #00C2FF
    static let amber = Color(red: 1.0, green: 0.722, blue: 0.0) // #FFB800

    // MARK: - 统一状态颜色
    enum StateColors {
        static let green = Color(red: 0.0, green: 1.0, blue: 0.616)       // #00FF9D
        static let yellow = Color(red: 1.0, green: 0.843, blue: 0.0)      // #FFD700
        static let orange = Color(red: 1.0, green: 0.549, blue: 0.0)      // #FF8C00
        static let red = Color(red: 1.0, green: 0.231, blue: 0.188)       // #FF3B30
        static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)  // #BF5AF2
        static let orangeRed = Color(red: 1.0, green: 0.271, blue: 0.0)   // #FF4500
        static let gray = Color(red: 0.420, green: 0.451, blue: 0.498)    // #6B7280
        static let mutedYellow = Color(red: 0.722, green: 0.525, blue: 0.043) // #B8860B
    }
}

// MARK: - 字体系统
struct PulseFonts {
    static let displayTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let displayHeading = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let displaySubheading = Font.system(size: 16, weight: .medium, design: .rounded)
    static let displayLarge = Font.system(size: 32, weight: .bold)
    static let headline = Font.system(size: 15, weight: .semibold)
    static let label = Font.system(size: 12, weight: .medium)

    static let body = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let bodyMedium = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let caption = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let micro = Font.system(size: 9, weight: .medium, design: .monospaced)

    static let monoLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let monoLarge = Font.system(size: 22, weight: .semibold, design: .monospaced)

    static let tabular = Font.system(size: 13, weight: .medium, design: .monospaced)
        .monospacedDigit()
    static let tabularLarge = Font.system(size: 22, weight: .semibold, design: .monospaced)
        .monospacedDigit()
}

// MARK: - 间距系统 (4pt 栅格)
struct PulseSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - 圆角系统 (ProofAlpha: 锐利风格)
struct PulseRadii {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let card: CGFloat = 14
    static let lg: CGFloat = 16
    static let badge: CGFloat = 6
    static let button: CGFloat = 8
    static let circle: CGFloat = 999
}

// MARK: - Liquid Glass Tokens
struct PulseGlass {
    static let accentOverlay = PulseColors.accent.opacity(0.06)
    static let accentBorder = PulseColors.accent.opacity(0.15)
    static let accentBorderHover = PulseColors.accent.opacity(0.30)
    static let cornerRadius: CGFloat = PulseRadii.card

    // 液态玻璃增强 — 更深的模糊与折射感
    static let modalBackdrop = Color.black.opacity(0.45)
    static let modalSurface = Color(red: 0.094, green: 0.094, blue: 0.106).opacity(0.75)
    static let sheetRadius: CGFloat = 20

    // 主题相关 — 需要从 PulseColors 实例读取
    static func surfaceTint(_ colors: PulseColors) -> Color { colors.background.opacity(0.10) }
    static func subtleBorder(_ colors: PulseColors) -> Color {
        colors.themeManager.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }
}

// MARK: - 阴影系统
struct PulseShadow {
    // 主题相关 — 需要从 PulseColors 实例读取
    static func card(_ colors: PulseColors) -> ShadowStyle {
        let dark = colors.themeManager.isDark
        return ShadowStyle(color: dark ? .black.opacity(0.3) : .black.opacity(0.08), radius: 3, y: 1)
    }
    static func elevated(_ colors: PulseColors) -> ShadowStyle {
        let dark = colors.themeManager.isDark
        return ShadowStyle(color: dark ? .black.opacity(0.4) : .black.opacity(0.12), radius: 8, y: 2)
    }
    static let glow = ShadowStyle(color: PulseColors.accent.opacity(0.2), radius: 12, y: 0)
    static func subtle(_ colors: PulseColors) -> ShadowStyle {
        let dark = colors.themeManager.isDark
        return ShadowStyle(color: dark ? .black.opacity(0.2) : .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
    let x: CGFloat

    init(color: Color, radius: CGFloat, y: CGFloat, x: CGFloat = 0) {
        self.color = color
        self.radius = radius
        self.y = y
        self.x = x
    }
}

extension View {
    func applyShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - 动画预设
struct PulseAnimation {
    static let springDefault = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let easeOutFast = Animation.easeOut(duration: 0.15)
    static let easeOutMedium = Animation.easeOut(duration: 0.25)
    static let staggerDelay: Double = 0.035
    static let workspaceTransition = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let cardEntry = Animation.spring(response: 0.4, dampingFraction: 0.75)
}
