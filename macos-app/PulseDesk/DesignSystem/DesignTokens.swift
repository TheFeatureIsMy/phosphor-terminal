// DesignTokens.swift — Krypton 专业交易终端设计系统

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let components = (
            r: Double((value >> 16) & 0xff) / 255.0,
            g: Double((value >> 8) & 0xff) / 255.0,
            b: Double(value & 0xff) / 255.0
        )

        self.init(red: components.r, green: components.g, blue: components.b)
    }
}

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

// MARK: - Krypton 品牌色

enum KryptonColor {
    static let background = Color(hex: "#12151f")
    static let surface = Color(hex: "#171b26")
    static let surfaceHover = Color(hex: "#1e2232")
    static let card = Color(hex: "#171b26")
    static let cardHover = Color(hex: "#222838")
    static let ink = Color(hex: "#0c0e17")

    static let amber = Color(hex: "#f7a600")
    static let amberActive = Color(hex: "#d48e00")
    static let amberSoft = Color(hex: "#f7a600").opacity(0.08)
    static let amberSpotlight = Color(hex: "#f7a600").opacity(0.10)
    static let amberCenter = Color(hex: "#ffd000")

    static let green = Color(hex: "#00c087")
    static let greenSoft = Color(hex: "#00c087").opacity(0.08)

    static let red = Color(hex: "#f6465d")
    static let redSoft = Color(hex: "#f6465d").opacity(0.08)

    static let border = Color(hex: "#202533")
    static let borderHover = Color(hex: "#2d3546")

    static let primaryText = Color.white
    static let secondaryText = Color(hex: "#848e9c")
}

// MARK: - 兼容旧组件的 Krypton 色彩系统

@Observable
class PulseColors {
    let themeManager: ThemeManager

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    private var isDark: Bool { themeManager.current == .dark }

    static let accent = KryptonColor.amber
    static let accentLight = KryptonColor.amberActive
    static let accentDim = KryptonColor.amberSoft

    var profit: Color { isDark ? KryptonColor.green : KryptonColor.green }
    var loss: Color { isDark ? KryptonColor.red : KryptonColor.red }
    static let loss = KryptonColor.red

    var background: Color { isDark ? KryptonColor.background : KryptonColor.surface }
    var cardBackground: Color { isDark ? KryptonColor.card : KryptonColor.surface }
    var surface: Color { isDark ? KryptonColor.surface : KryptonColor.background }
    var surfaceElevated: Color { isDark ? KryptonColor.cardHover : KryptonColor.surfaceHover }
    var surfaceHover: Color { isDark ? KryptonColor.surfaceHover : KryptonColor.cardHover }
    var surfaceActive: Color { isDark ? KryptonColor.amberSoft : KryptonColor.surfaceHover }

    var textPrimary: Color { isDark ? KryptonColor.primaryText : KryptonColor.ink }
    var textSecondary: Color { isDark ? KryptonColor.secondaryText : KryptonColor.secondaryText }
    var textMuted: Color { isDark ? KryptonColor.secondaryText : KryptonColor.secondaryText }

    var border: Color { isDark ? KryptonColor.border : KryptonColor.border }
    var borderHover: Color { isDark ? KryptonColor.borderHover : KryptonColor.borderHover }
    static let borderAccent = KryptonColor.amberSoft

    static let warning = KryptonColor.amber
    static let danger = KryptonColor.red
    static let info = Color(hex: "#00c2ff")
    static let success = KryptonColor.green

    static let statusActive = KryptonColor.green
    static let statusPaused = KryptonColor.amber
    var statusDraft: Color { isDark ? Color(hex: "#3f4656") : Color(hex: "#848e9c") }
    static let statusError = KryptonColor.red

    static let purple = Color(hex: "#a855f7")
    static let cyan = Color(hex: "#00c2ff")
    static let amber = KryptonColor.amber

    enum StateColors {
        static let green = KryptonColor.green
        static let yellow = KryptonColor.amber
        static let orange = KryptonColor.amberActive
        static let red = KryptonColor.red
        static let purple = Color(hex: "#bf5af2")
        static let orangeRed = Color(hex: "#ff4500")
        static let gray = Color(hex: "#6b7280")
        static let mutedYellow = Color(hex: "#b8860b")
    }
}

// MARK: - Krypton 字体系统

struct PulseFonts {
    static let displayTitle = Font.system(size: 28, weight: .bold)
    static let displayHeading = Font.system(size: 20, weight: .semibold)
    static let displaySubheading = Font.system(size: 16, weight: .medium)

    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionMedium = Font.system(size: 11, weight: .medium)
    static let micro = Font.system(size: 9, weight: .medium)

    static let monoLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let monoLarge = Font.system(size: 22, weight: .semibold, design: .monospaced)

    static let tabular = Font.system(size: 13, weight: .medium, design: .monospaced).monospacedDigit()
    static let tabularLarge = Font.system(size: 22, weight: .semibold, design: .monospaced).monospacedDigit()
}

// MARK: - Krypton 间距系统

struct PulseSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Krypton 圆角系统

struct PulseRadii {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let card: CGFloat = 10
    static let lg: CGFloat = 10
    static let badge: CGFloat = 4
    static let button: CGFloat = 6
    static let circle: CGFloat = 999
}

// MARK: - Krypton 玻璃与边框

struct PulseGlass {
    static let accentOverlay = KryptonColor.amberSpotlight
    static let accentBorder = KryptonColor.amberSoft
    static let accentBorderHover = KryptonColor.borderHover
    static let cornerRadius: CGFloat = PulseRadii.card

    static let modalBackdrop = Color.black.opacity(0.45)
    static let modalSurface = KryptonColor.surface
    static let sheetRadius: CGFloat = 10

    static func surfaceTint(_ colors: PulseColors) -> Color { colors.surface.opacity(0.10) }
    static func subtleBorder(_ colors: PulseColors) -> Color { colors.border }
}

// MARK: - Krypton 阴影系统

struct PulseShadow {
    static func card(_ colors: PulseColors) -> ShadowStyle {
        ShadowStyle(color: .black.opacity(0.18), radius: 3, y: 1)
    }
    static func elevated(_ colors: PulseColors) -> ShadowStyle {
        ShadowStyle(color: KryptonColor.amber.opacity(0.04), radius: 10, y: 2)
    }
    static let glow = ShadowStyle(color: KryptonColor.amber.opacity(0.12), radius: 12, y: 0)
    static func subtle(_ colors: PulseColors) -> ShadowStyle {
        ShadowStyle(color: .black.opacity(0.12), radius: 2, y: 1)
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
}
