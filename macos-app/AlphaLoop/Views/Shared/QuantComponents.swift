// QuantComponents.swift — 量化交易工作台基础组件层
// 统一页头、固定结构指标块、数字跳动、区块卡片 —— 消除卡片大小/间距/风格漂移。
// 交易员视角:高数据密度、tabular 等宽数字、实时跳动、专业终端质感。

import SwiftUI

// MARK: - QuantPageHeader — 全站统一页头
// 结构:eyebrow("// SECTION") + 大写等宽标题 + 副标题(可选) + 右侧 trailing 槽。
// 固定高度语义,所有页面共用,消除各页面自写 header 导致的高度/风格不一。
struct QuantPageHeader<Trailing: View>: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(PulseFonts.body(13, .semibold))
                    .foregroundStyle(PulseColors.accent)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(title)
                    .font(PulseFonts.display(28, .bold))
                    .foregroundStyle(colors.textPrimary)
                    .tracking(-0.3)
                if let subtitle {
                    Text(subtitle)
                        .font(PulseFonts.body(14))
                        .foregroundStyle(colors.textSecondary)
                }
            }
            Spacer(minLength: PulseSpacing.md)
            trailing()
        }
        .id(settingsState.language)
    }
}

extension QuantPageHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

// MARK: - AnimatedNumber — 弹簧数字跳动(量化台灵魂:实时数字变化)
// 封装 spring + numericText 过渡,首次出场从 0 跳到目标值,后续变化平滑过渡。
struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.2f"
    var prefix: String = ""
    var suffix: String = ""
    var font: Font = PulseFonts.tabularLarge
    var color: Color? = nil
    var placeholder: String = "—"
    var animateOnAppear: Bool = true

    @Environment(PulseColors.self) private var colors
    @State private var displayValue: Double = 0
    @State private var hasAnimated = false

    var body: some View {
        Text(value == 0 && !placeholder.isEmpty
             ? placeholder
             : "\(prefix)\(String(format: format, displayValue))\(suffix)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color ?? colors.textPrimary)
            .contentTransition(.numericText())
            .onAppear {
                guard animateOnAppear, !hasAnimated else {
                    displayValue = value
                    return
                }
                hasAnimated = true
                withAnimation(.spring(response: 1.2, dampingFraction: 0.72)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - MetricTile — 固定结构指标块(消除卡片大小不一致的核心)
// 统一结构:label(顶部弱化) + value(大号等宽数字) + delta(可选涨跌)。
// 所有指标块共用同一垂直节律与内边距,横向排列时天然等宽等高。
struct MetricTile: View {
    @Environment(PulseColors.self) private var colors

    let label: String
    let value: String
    var delta: String? = nil
    var deltaPositive: Bool = true
    var valueColor: Color? = nil
    var icon: String? = nil
    /// 是否显示为独立卡片(true=带背景边框,false=裸块用于分隔线布局)
    var boxed: Bool = true

    @State private var isHovering = false

    private var accentColor: Color { valueColor ?? PulseColors.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .fill(accentColor.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseRadii.sm)
                                .stroke(accentColor.opacity(0.22), lineWidth: 0.8)
                        )
                }
                Text(label)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .lineLimit(1)
            }

            Text(value)
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(valueColor ?? colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)

            if let delta {
                HStack(spacing: 3) {
                    Image(systemName: deltaPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(delta)
                        .font(PulseFonts.captionMedium)
                }
                .foregroundStyle(deltaPositive ? PulseColors.bullish : PulseColors.bearish)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(boxed ? PulseSpacing.md : 0)
        .background {
            if boxed {
                RoundedRectangle(cornerRadius: PulseRadii.md)
                    .fill(isHovering ? colors.surfaceElevated : colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.md)
                            .stroke(isHovering ? colors.borderHover : colors.border, lineWidth: 1)
                    )
            }
        }
        .scaleEffect(isHovering && boxed ? 1.015 : 1.0)
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
        }
    }
}

// MARK: - MetricTileGrid — 等宽指标块网格(强制统一尺寸)
// 传入 [MetricTile] 数据,自动等宽排布;超过每行列数自动换行。
// 用固定 columns + 等间距保证卡片大小完全一致。
struct MetricTileGrid: View {
    let tiles: [MetricTileData]
    var columns: Int = 4
    var spacing: CGFloat = PulseSpacing.sm

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(tiles) { tile in
                MetricTile(
                    label: tile.label,
                    value: tile.value,
                    delta: tile.delta,
                    deltaPositive: tile.deltaPositive,
                    valueColor: tile.valueColor,
                    icon: tile.icon
                )
            }
        }
    }
}

struct MetricTileData: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var delta: String? = nil
    var deltaPositive: Bool = true
    var valueColor: Color? = nil
    var icon: String? = nil
}

// MARK: - QuantSectionHeader — 区块小标题(带 accent 竖条)
// 统一区块内标题风格,替代散落的手写 section header。
struct QuantSectionHeader<Trailing: View>: View {
    @Environment(PulseColors.self) private var colors
    let title: String
    var accent: Color = PulseColors.accent
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: PulseSpacing.xs) {
            RoundedRectangle(cornerRadius: 1)
                .fill(accent)
                .frame(width: 3, height: 14)
            Text(title)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
            Spacer(minLength: PulseSpacing.xs)
            trailing()
        }
    }
}

extension QuantSectionHeader where Trailing == EmptyView {
    init(title: String, accent: Color = PulseColors.accent) {
        self.init(title: title, accent: accent, trailing: { EmptyView() })
    }
}
