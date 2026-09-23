// DesignTokens.swift — AlphaLoop 设计系统
// VOLT 电光风格（新生代 Degen / 电光柠檬黄）— 唯一主题
// 参考: design-previews-v3/dashboard-volt.html + docs/superpowers/specs/2026-08-21-v3-redesign-design.md

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

// MARK: - 主题运行时(全局)
// 供静态颜色计算属性读取当前主题;ThemeManager 在 init/didSet 中同步。
// 静态语义色借此实现主题感知,数百个调用点零改动自动适配。
/// Bool 读写在主题切换瞬间的竞态无害(最差一帧旧色);@unchecked Sendable 规避严格并发检查
final class ThemeRuntimeFlag: @unchecked Sendable {
    var isDark = true
}

enum ThemeRuntime {
    private static let flag = ThemeRuntimeFlag()
    static var isDark: Bool { flag.isDark }
    static func setIsDark(_ value: Bool) { flag.isDark = value }
}

// MARK: - 主题管理器
// 差异化双主题:
//   · dark  = VOLT Terminal(夜盘终端) — 近黑底 + 电光柠檬黄 + 霓虹数据色 + 发光层次
//   · light = VOLT Daylight(晨报纸面) — 暖纸底 + 印刷油墨数据色 + 真实柔和阴影;柠檬黄退为荧光笔标记色
@Observable
class ThemeManager {
    enum Theme: String, CaseIterable {
        case dark, light
        var label: String { self == .dark ? "暗黑" : "明亮" }
        var icon: String { self == .dark ? "moon.fill" : "sun.max.fill" }
    }

    var current: Theme = .dark {
        didSet {
            ThemeRuntime.setIsDark(current == .dark)
            UserDefaults.standard.set(current.rawValue, forKey: "appTheme")
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "appTheme"),
           let t = Theme(rawValue: raw) {
            current = t
        }
        // 调试/截图：--theme light|dark
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--theme"), idx + 1 < args.count,
           let t = Theme(rawValue: args[idx + 1]) {
            current = t
        }
        ThemeRuntime.setIsDark(current == .dark)
    }

    func toggle() {
        withAnimation(PulseAnimation.easeOutMedium) {
            current = current == .dark ? .light : .dark
        }
    }

    var isDark: Bool { current == .dark }
}

// MARK: - 颜色系统（VOLT 深色）
// @Observable 确保主题切换时 SwiftUI 自动重渲染
@Observable
class PulseColors {
    let themeManager: ThemeManager

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    private var isDark: Bool { themeManager.isDark }

    // 品牌强调色 — VOLT 电光柠檬黄(唯一主色,两主题共用的荧光笔签名)
    static let accent = Color(hex: "D8FF3D")
    static let accentLight = Color(hex: "E4FF70")
    static let accentDim = Color(hex: "D8FF3D").opacity(0.12)
    /// accent 选中表面 — 暗色=暗橄榄 tint / 亮色=浅柠檬荧光笔底
    static var accentSoft: Color { ThemeRuntime.isDark ? Color(hex: "22260F") : Color(hex: "E9F9C0") }
    /// accent 作文字/图标时的主题感知变体(亮色=深橄榄,白纸对比 5.5:1)
    static var accentText: Color { ThemeRuntime.isDark ? accent : Color(hex: "5A7A00") }
    /// 主题感知的 accent 表面(选中/激活背景)
    var accentSurface: Color { PulseColors.accentSoft }
    /// 主题感知的 accent 文字色
    var accentInk: Color { PulseColors.accentText }
    /// 电光黄底之上的前景色 —— 近黑字(VOLT 主按钮黑字)。
    static let onAccent = Color(hex: "0A0A0C")
    /// 辅助紫(极少量强调) — 亮色降明度提饱和(印刷级)
    static var violet: Color { ThemeRuntime.isDark ? Color(hex: "8B7CFF") : Color(hex: "6B54E8") }
    /// 兼容旧引用：coral 映射为警示橙
    static var coral: Color { warning }

    // 涨跌语义色 — 暗色=霓虹数据色 / 亮色=印刷油墨色(对比 4.5:1+)
    static var bullish: Color { ThemeRuntime.isDark ? Color(hex: "3DF584") : Color(hex: "15803D") }   // 涨 / 多头 / 盈利 / 买入
    static var bearish: Color { ThemeRuntime.isDark ? Color(hex: "FF4D6D") : Color(hex: "E11D48") }   // 跌 / 空头 / 亏损 / 卖出
    static var bullishSoft: Color { bullish.opacity(0.12) }
    static var bearishSoft: Color { bearish.opacity(0.12) }
    /// 涨跌实心底之上的文字色 — 暗色=近黑压霓虹 / 亮色=白字压油墨
    static var onBullish: Color { ThemeRuntime.isDark ? onAccent : .white }
    static var onBearish: Color { .white }

    // 盈亏色
    var profit: Color { PulseColors.bullish }
    var loss: Color { PulseColors.bearish }
    static var loss: Color { bearish }

    // 背景色 — 亮色=纯白(卡片同白,靠边框+柔和阴影分层 — shadow-as-border)
    var background: Color { isDark ? Color(hex: "0A0A0C") : Color(hex: "FFFFFF") }

    // 卡片底色
    var cardBackground: Color { isDark ? Color(hex: "121216") : Color(hex: "FFFFFF") }

    // 表面色 — 层次(亮色中性微暖,与背景拉开明度差)
    var surface: Color { isDark ? Color(hex: "17171C") : Color(hex: "EFF0F3") }
    var surfaceElevated: Color { isDark ? Color(hex: "1B1B21") : Color(hex: "FFFFFF") }
    var surfaceHover: Color { isDark ? Color(hex: "1E1E25") : Color(hex: "F3F4F6") }
    var surfaceActive: Color { isDark ? Color(hex: "22260F") : Color(hex: "F1F7D8") }   // volt-tinted active

    /// 导航选中底 — 暗色=暗橄榄 tint / 亮色=荧光笔实底(nav-state-active 最强指示)
    var navSelection: Color { isDark ? PulseColors.accentSoft : PulseColors.accent }
    /// 导航选中底之上的前景色
    var onNavSelection: Color { isDark ? textPrimary : PulseColors.onAccent }
    /// 导航选中指示竖条 — 暗色=电光 lime / 亮色=近黑(lime 底上必须深色)
    var navSelectionIndicator: Color { isDark ? PulseColors.accent : PulseColors.onAccent }

    // 文字色 — 亮色=中性近黑(退暖)
    var textPrimary: Color { isDark ? Color(hex: "F5F6F8") : Color(hex: "16181C") }
    var textSecondary: Color { isDark ? Color(hex: "9BA0AE") : Color(hex: "4A5058") }
    var textMuted: Color { isDark ? Color(hex: "60656F") : Color(hex: "8A9099") }

    // 描边色 — 亮色=中性浅灰(米白底上保持白卡边界可见)
    var border: Color { isDark ? Color(hex: "26262C") : Color(hex: "D8DADF") }
    var borderHover: Color { isDark ? Color(hex: "3A3A44") : Color(hex: "BEC2C9") }
    static let borderAccent = Color(hex: "D8FF3D").opacity(0.45)

    // 语义色 — 亮色=降明度印刷级(琥珀 #B45309 / 绯红 #E11D48,白纸对比 4.5:1+)
    static var warning: Color { ThemeRuntime.isDark ? Color(hex: "FFB84D") : Color(hex: "B45309") }
    static var danger: Color { bearish }
    static var info: Color { violet }
    static var success: Color { bullish }
    static var warningSoft: Color { warning.opacity(0.12) }

    // 状态色
    static var statusActive: Color { bullish }
    static var statusPaused: Color { warning }
    var statusDraft: Color { isDark ? Color(hex: "60656F") : Color(hex: "8B877A") }
    static var statusError: Color { bearish }

    // 特殊色 — VOLT: purple 映射到辅助紫; cyan 映射到 accent 文字色
    static var purple: Color { violet }
    static var cyan: Color { accentText }
    static var amber: Color { warning }

    // MARK: - 统一状态颜色(主题感知:暗色=霓虹 / 亮色=印刷)
    enum StateColors {
        static var green: Color { PulseColors.bullish }       // 健康/运行/上涨
        static var yellow: Color { PulseColors.warning }
        static var orange: Color { PulseColors.warning }
        static var red: Color { PulseColors.bearish }
        static var purple: Color { PulseColors.violet }       // 辅助紫
        static var orangeRed: Color { ThemeRuntime.isDark ? Color(hex: "FF7A59") : Color(hex: "C2410C") }
        static var gray: Color { ThemeRuntime.isDark ? Color(hex: "60656F") : Color(hex: "8B877A") }
        static var mutedYellow: Color { PulseColors.warning }
        static var amber: Color { PulseColors.warning }
        static var amberActive: Color { ThemeRuntime.isDark ? Color(hex: "FFD08A") : Color(hex: "B45309") }
        static var amberSpotlight: Color { PulseColors.warning.opacity(0.10) }
        static var redSoft: Color { PulseColors.bearish.opacity(0.12) }
        static var greenSoft: Color { PulseColors.bullish.opacity(0.12) }
        static var card: Color { ThemeRuntime.isDark ? Color(hex: "121216") : Color(hex: "FFFFFF") }
        static var background: Color { ThemeRuntime.isDark ? Color(hex: "0A0A0C") : Color(hex: "FFFFFF") }
        static var surfaceHover: Color { ThemeRuntime.isDark ? Color(hex: "1E1E25") : Color(hex: "F3F4F6") }
    }
}

// MARK: - 字体系统 (VOLT: Archivo 展示 + Space Grotesk UI + JetBrains Mono 数据)
// 自定义字体未注册时,.custom 自动回退到系统字体,故未打包字体前也可运行。
struct PulseFonts {
    // 字体族名(打包 ttf 后即生效)
    static let displayFamily = "Archivo"
    static let bodyFamily = "Space Grotesk"
    static let monoFamily = "JetBrains Mono"

    /// Archivo 展示字体(大字重标题/数字)
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(displayFamily, size: size).weight(weight)
    }
    /// Space Grotesk 正文字体
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(bodyFamily, size: size).weight(weight)
    }
    /// JetBrains Mono 数据字体(标签/读数/代码)
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom(monoFamily, size: size).weight(weight)
    }

    // 展示字体(Archivo)
    static let displayTitle = display(28, .bold)
    static let displayHeading = display(20, .bold)
    static let displaySubheading = display(16, .semibold)
    static let displayLarge = display(32, .heavy)
    static let headline = body(15, .semibold)
    static let label = body(12, .medium)

    // 正文(Space Grotesk)
    static let body = body(14, .regular)
    static let bodyMedium = body(14, .medium)
    static let caption = body(12, .regular)
    static let captionMedium = body(12, .medium)
    static let micro = mono(10, .medium)

    // 小标签 — VOLT 用 JetBrains Mono(数据语感)
    static let monoLabel = mono(11, .semibold)
    static let monoLarge = mono(22, .bold)

    // tabular 数字 — JetBrains Mono 等宽对齐
    static let tabular = mono(14, .medium).monospacedDigit()
    static let tabularLarge = display(22, .bold).monospacedDigit()
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

    /// 页面内容最大宽度(VOLT 稿 1340)
    static let contentMaxWidth: CGFloat = 1340
    /// 页面水平内边距
    static let pageHorizontal: CGFloat = 26
}

// MARK: - 圆角系统 (VOLT: 中小圆角,干练)
// VOLT SHAPE LOCK — 统一中小圆角,硬朗现代:
//   · 小徽章 / pill / tag / 芯片    → badge (8)
//   · 按钮 / 输入框 / 分段控件      → button (10)
//   · 卡片 / 面板 / 抽屉 / 大容器  → card (14)
//   · 圆形指示(点/环)              → circle (999)
struct PulseRadii {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let card: CGFloat = 14
    static let lg: CGFloat = 16
    static let badge: CGFloat = 8
    static let button: CGFloat = 10
    static let circle: CGFloat = 999
}

// MARK: - 卡片 / 表面 Tokens (VOLT: 炭卡 + 硬边框 + 电光发光)
struct PulseGlass {
    static let accentOverlay = PulseColors.accent.opacity(0.08)
    static let accentBorder = PulseColors.accent.opacity(0.30)
    static let accentBorderHover = PulseColors.accent.opacity(0.55)
    static let cornerRadius: CGFloat = PulseRadii.card

    // 模态 — 暗色:深遮罩+炭浮层 / 亮色:暖墨浅遮罩+白纸浮层(消除弹窗割裂)
    static var modalBackdrop: Color { ThemeRuntime.isDark ? Color(hex: "000000").opacity(0.55) : Color(hex: "1A1710").opacity(0.32) }
    static var modalSurface: Color { ThemeRuntime.isDark ? Color(hex: "17171C") : Color(hex: "FFFFFF") }
    static let sheetRadius: CGFloat = 16

    static func surfaceTint(_ colors: PulseColors) -> Color { colors.surface }
    static func subtleBorder(_ colors: PulseColors) -> Color { colors.border }
}

// MARK: - 阴影系统 (差异化深度模型)
// 暗色:阴影几乎不可见,深度靠硬边框+电光发光;亮色:真实柔和投影(暖墨,纸面层次)。
private let voltShadowColor = Color(hex: "000000")
private let paperShadowColor = Color(hex: "14161A")
struct PulseShadow {
    static func card(_ colors: PulseColors) -> ShadowStyle {
        ThemeRuntime.isDark
            ? ShadowStyle(color: voltShadowColor.opacity(0.35), radius: 10, y: 4)
            : ShadowStyle(color: paperShadowColor.opacity(0.10), radius: 16, y: 6)
    }
    static func elevated(_ colors: PulseColors) -> ShadowStyle {
        ThemeRuntime.isDark
            ? ShadowStyle(color: voltShadowColor.opacity(0.5), radius: 20, y: 10)
            : ShadowStyle(color: paperShadowColor.opacity(0.14), radius: 28, y: 14)
    }
    /// VOLT 招牌发光 — 暗色=电光黄光晕 / 亮色=极淡橄榄荧光晕
    static var glow: ShadowStyle {
        ThemeRuntime.isDark
            ? ShadowStyle(color: PulseColors.accent.opacity(0.35), radius: 18, y: 0)
            : ShadowStyle(color: Color(hex: "5A7A00").opacity(0.14), radius: 16, y: 0)
    }
    /// 浮层/抽屉/弹窗投影 — 暗色=重黑 / 亮色=暖墨柔影
    static var modal: ShadowStyle {
        ThemeRuntime.isDark
            ? ShadowStyle(color: voltShadowColor.opacity(0.5), radius: 30, y: 12)
            : ShadowStyle(color: paperShadowColor.opacity(0.16), radius: 30, y: 12)
    }
    static func subtle(_ colors: PulseColors) -> ShadowStyle {
        ThemeRuntime.isDark
            ? ShadowStyle(color: voltShadowColor.opacity(0.25), radius: 6, y: 2)
            : ShadowStyle(color: paperShadowColor.opacity(0.05), radius: 5, y: 2)
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

// MARK: - 动画预设 (VOLT 语法)
struct PulseAnimation {
    // VOLT 缓动:slam 入场回弹(cubic-bezier(0.16,0.84,0.3,1))
    static let springDefault = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let easeOutFast = Animation.easeOut(duration: 0.15)
    static let easeOutMedium = Animation.easeOut(duration: 0.25)
    /// VOLT slam 入场(模块/卡片):translateY+scale 快出回弹
    static let slam = Animation.timingCurve(0.16, 0.84, 0.3, 1, duration: 0.5)
    /// VOLT 标准出场缓动(曲线描线/进度条/计数)
    static let protocolEase = Animation.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.6)
    /// VOLT 慢速描线动画(权益曲线/水位条)
    static let drawIn = Animation.timingCurve(0.3, 0.7, 0.2, 1, duration: 1.2)
    /// 卡片 hover(快速回弹)
    static let hoverLift = Animation.spring(response: 0.22, dampingFraction: 0.8)
    static let staggerDelay: Double = 0.04
    static let workspaceTransition = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let cardEntry = slam
}
