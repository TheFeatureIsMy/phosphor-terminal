// DesignTokens.swift — AlphaLoop 设计系统
// Protocol 风格（机构 DeFi / 浅色钴蓝双色）— 唯一主题
// 参考: design-previews-v2/03-protocol.html + _specs/STYLE-SYSTEM.md §③ PROTOCOL

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
// Protocol 风格为唯一浅色主题；暗色分支已废弃（保留 API 兼容）。
@Observable
class ThemeManager {
    enum Theme: String, CaseIterable {
        case dark, light
        var label: String { self == .dark ? "暗黑" : "明亮" }
        var icon: String { self == .dark ? "moon.fill" : "sun.max.fill" }
    }

    // 锁定为浅色 protocol 主题；写入无效（保留 setter 以兼容既有调用点）。
    var current: Theme = .light {
        didSet { current = .light }
    }

    init() {}

    func toggle() {
        // 主题已锁定为 protocol 浅色，切换为空操作。
    }

    var isDark: Bool { false }
}

// MARK: - 颜色系统（双主题）
// @Observable 确保主题切换时 SwiftUI 自动重渲染
@Observable
class PulseColors {
    let themeManager: ThemeManager

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    private var isDark: Bool { false }

    // 品牌强调色 — Protocol 钴蓝(唯一主色,STYLE-SYSTEM §③)
    static let accent = Color(hex: "3D5AFE")
    static let accentLight = Color(hex: "5B72FF")
    static let accentDim = Color(hex: "3D5AFE").opacity(0.10)
    static let accentSoft = Color(hex: "EAEEFF")   // accent-soft tint
    /// 钴蓝底之上的前景色 —— 白字(protocol 主按钮白字)。
    static let onAccent = Color(hex: "FFFFFF")
    /// 辅助珊瑚色(极少量强调)
    static let coral = Color(hex: "FF7A59")

    // 涨跌语义色 — 绿涨红跌(protocol: up #12B76A / down #F04438)
    static let bullish = Color(hex: "12B76A")   // 涨 / 多头 / 盈利 / 买入
    static let bearish = Color(hex: "F04438")   // 跌 / 空头 / 亏损 / 卖出
    static let bullishSoft = Color(hex: "E6F7EF")
    static let bearishSoft = Color(hex: "FDECEA")

    // 盈亏色
    var profit: Color { Color(hex: "12B76A") }
    var loss: Color { Color(hex: "F04438") }
    static let loss = Color(hex: "F04438")

    // 背景色 — protocol 冷白
    var background: Color { Color(hex: "F6F7FB") }

    // 卡片底色 — protocol 纯白卡
    var cardBackground: Color { Color(hex: "FFFFFF") }

    // 表面色 — 浅色 tint 层次
    var surface: Color { Color(hex: "F1F3FA") }
    var surfaceElevated: Color { Color(hex: "FFFFFF") }
    var surfaceHover: Color { Color(hex: "EEF0F7") }
    var surfaceActive: Color { Color(hex: "EAEEFF") }

    // 文字色 — protocol 墨蓝阶
    var textPrimary: Color { Color(hex: "0F1524") }
    var textSecondary: Color { Color(hex: "5A6480") }
    var textMuted: Color { Color(hex: "8A93AD") }

    // 描边色 — protocol 极轻边框
    var border: Color { Color(hex: "E6E9F2") }
    var borderHover: Color { Color(hex: "CDD3E6") }
    static let borderAccent = Color(hex: "3D5AFE").opacity(0.40)

    // 语义色
    static let warning = Color(hex: "F59E0B")
    static let danger = Color(hex: "F04438")
    static let info = Color(hex: "3D5AFE")
    static let success = Color(hex: "12B76A")
    static let warningSoft = Color(hex: "FEF4E2")

    // 状态色
    static let statusActive = Color(hex: "20B26C")
    static let statusPaused = Color(hex: "F59E0B")
    var statusDraft: Color { Color(hex: "8A93AD") }
    static let statusError = Color(hex: "F04438")

    // 特殊色 — protocol 无紫;cyan/purple 别名映射到品牌钴蓝/珊瑚以兼容既有引用
    static let purple = Color(hex: "3D5AFE")   // 映射到钴蓝(protocol 无紫)
    static let cyan = Color(hex: "3D5AFE")     // 映射到钴蓝
    static let amber = Color(hex: "F59E0B")

    // MARK: - 统一状态颜色(protocol 浅色)
    enum StateColors {
        static let green = Color(hex: "12B76A")       // 健康/运行/上涨
        static let yellow = Color(hex: "F59E0B")
        static let orange = Color(hex: "FF7A59")      // protocol 珊瑚
        static let red = Color(hex: "F04438")
        static let purple = Color(hex: "3D5AFE")      // 映射到钴蓝(无紫)
        static let orangeRed = Color(hex: "FF7A59")
        static let gray = Color(hex: "8A93AD")
        static let mutedYellow = Color(hex: "B4740B")
        static let amber = Color(hex: "F59E0B")
        static let amberActive = Color(hex: "D9880A")
        static let amberSpotlight = Color(hex: "F59E0B").opacity(0.10)
        static let redSoft = Color(hex: "FDECEA")
        static let greenSoft = Color(hex: "E6F7EF")
        static let card = Color(hex: "FFFFFF")            // protocol 白卡
        static let background = Color(hex: "F6F7FB")      // protocol 冷白底
        static let surfaceHover = Color(hex: "EEF0F7")    // protocol inset
    }
}

// MARK: - 字体系统 (Protocol: Space Grotesk 标题 + Inter 正文)
// 自定义字体未注册时,.custom 自动回退到系统字体,故未打包字体前也可运行。
struct PulseFonts {
    // 字体族名(打包 ttf 后即生效)
    static let displayFamily = "Space Grotesk"
    static let bodyFamily = "Inter"

    /// Space Grotesk 展示字体
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .custom(displayFamily, size: size).weight(weight)
    }
    /// Inter 正文字体
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(bodyFamily, size: size).weight(weight)
    }

    // 展示字体(Space Grotesk)
    static let displayTitle = display(28, .bold)
    static let displayHeading = display(20, .semibold)
    static let displaySubheading = display(16, .medium)
    static let displayLarge = display(32, .bold)
    static let headline = body(15, .semibold)
    static let label = body(12, .medium)

    // 正文(Inter — protocol 禁止等宽当正文)
    static let body = body(14, .regular)
    static let bodyMedium = body(14, .medium)
    static let caption = body(12, .regular)
    static let captionMedium = body(12, .medium)
    static let micro = body(10, .medium)

    // 小标签 — protocol 用 Space Grotesk / Inter,不再等宽
    static let monoLabel = display(11, .semibold)
    static let monoLarge = display(22, .semibold)

    // tabular 数字 — 保留 tabularNumbers 特性用于金融对齐
    static let tabular = body(14, .medium).monospacedDigit()
    static let tabularLarge = display(22, .semibold).monospacedDigit()
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

    /// 页面内容最大宽度(protocol 稿 1240)
    static let contentMaxWidth: CGFloat = 1240
    /// 页面水平内边距
    static let pageHorizontal: CGFloat = 28
}

// MARK: - 圆角系统 (Protocol: 大圆角 16-20px)
// PROTOCOL SHAPE LOCK — 统一大圆角,柔和专业:
//   · 小徽章 / pill / tag / 内嵌状态块  → badge (10)
//   · 按钮 / 输入框 / 分段控件          → button (11)
//   · 卡片 / 面板 / 抽屉 / 大容器      → card (18) / lg (20)
//   · 圆形指示(点/环)               → circle (999)
struct PulseRadii {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 14
    static let card: CGFloat = 18
    static let lg: CGFloat = 20
    static let badge: CGFloat = 10
    static let button: CGFloat = 11
    static let circle: CGFloat = 999
}

// MARK: - 卡片 / 表面 Tokens (Protocol: 白卡 + 极轻边框 + 品牌色柔和阴影)
struct PulseGlass {
    static let accentOverlay = PulseColors.accent.opacity(0.05)
    static let accentBorder = PulseColors.accent.opacity(0.12)
    static let accentBorderHover = PulseColors.accent.opacity(0.28)
    static let cornerRadius: CGFloat = PulseRadii.card

    // 模态 — 浅色遮罩 + 白色浮层
    static let modalBackdrop = Color(hex: "0F1524").opacity(0.28)
    static let modalSurface = Color(hex: "FFFFFF")
    static let sheetRadius: CGFloat = 20

    static func surfaceTint(_ colors: PulseColors) -> Color { colors.surface }
    static func subtleBorder(_ colors: PulseColors) -> Color { colors.border }
}

// MARK: - 阴影系统 (Protocol: 阴影染品牌钴蓝,非纯黑)
private let protocolShadowColor = Color(hex: "3D5AFE")
struct PulseShadow {
    static func card(_ colors: PulseColors) -> ShadowStyle {
        ShadowStyle(color: protocolShadowColor.opacity(0.06), radius: 12, y: 4)
    }
    static func elevated(_ colors: PulseColors) -> ShadowStyle {
        ShadowStyle(color: protocolShadowColor.opacity(0.12), radius: 20, y: 8)
    }
    static let glow = ShadowStyle(color: PulseColors.accent.opacity(0.18), radius: 16, y: 0)
    static func subtle(_ colors: PulseColors) -> ShadowStyle {
        ShadowStyle(color: protocolShadowColor.opacity(0.04), radius: 6, y: 2)
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
    // Protocol 缓动:cubic-bezier(0.2,0.7,0.3,1) — 出场/曲线/进度统一
    static let springDefault = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let easeOutFast = Animation.easeOut(duration: 0.15)
    static let easeOutMedium = Animation.easeOut(duration: 0.25)
    /// protocol 标准出场缓动(曲线描线/进度条/计数)
    static let protocolEase = Animation.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.6)
    /// protocol 慢速描线动画(权益曲线/水位条)
    static let drawIn = Animation.timingCurve(0.3, 0.7, 0.2, 1, duration: 1.2)
    /// 卡片 hover 上浮(快速回弹)
    static let hoverLift = Animation.spring(response: 0.22, dampingFraction: 0.8)
    static let staggerDelay: Double = 0.05
    static let workspaceTransition = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let cardEntry = Animation.spring(response: 0.4, dampingFraction: 0.75)
}
