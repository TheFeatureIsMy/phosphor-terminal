// PositionsRiskCard.swift — Bento 卡片: 当前活跃多/空持仓
import SwiftUI

struct PositionsRiskCard: View {
    @Environment(PulseColors.self) private var colors
    let positions: [PositionWithAI]
    @State private var hoveredRowID: String?

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack {
                    TerminalLabel(text: "当前活跃多/空持仓")
                    Spacer()
                    Text("\(positions.count) 个活跃持仓")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }

                VStack(spacing: 0) {
                    // Table Header
                    HStack(spacing: 0) {
                        Text("品种 SYMBOL").frame(width: 110, alignment: .leading)
                        Text("方向 DIR").frame(width: 60, alignment: .center)
                        Text("最新盈亏 PNL (USDT)").frame(width: 140, alignment: .trailing)
                        Text("AI 建议 RECOMMEND").frame(width: 110, alignment: .center)
                        Text("风险 RISK").frame(width: 70, alignment: .trailing)
                    }
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .padding(.horizontal, PulseSpacing.sm)
                    .padding(.vertical, 8)
                    .background(colors.surface)

                    Divider().background(colors.border)

                    if positions.isEmpty {
                        VStack {
                            Spacer()
                            HStack(spacing: PulseSpacing.xs) {
                                StatusDot(status: .online)
                                Text("无活跃持仓")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textMuted)
                            }
                            Spacer()
                        }
                        .frame(height: 120)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(positions.enumerated()), id: \.element.id) { index, pos in
                                    PositionRow(position: pos, isHovered: hoveredRowID == pos.id)
                                        .staggeredAppearance(index: index)
                                        .onHover { hover in
                                            withAnimation(PulseAnimation.easeOutFast) {
                                                hoveredRowID = hover ? pos.id : nil
                                            }
                                        }
                                    if index < positions.count - 1 {
                                        Divider().background(colors.border.opacity(0.5))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.sm).stroke(colors.border, lineWidth: 1))
            }
        }
        .hoverEffect()
    }
}

struct PositionRow: View {
    @Environment(PulseColors.self) private var colors
    let position: PositionWithAI
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: PulseSpacing.xs) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(position.pnl >= 0 ? KryptonColor.green : KryptonColor.red)
                    .frame(width: 3, height: 18)
                Text(position.symbol)
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textPrimary)
                    .fontWeight(.bold)
            }
            .frame(width: 110, alignment: .leading)

            Text(position.direction == "long" ? "LONG 多" : "SHORT 空")
                .font(PulseFonts.micro)
                .fontWeight(.bold)
                .foregroundStyle(position.direction == "long" ? KryptonColor.green : KryptonColor.red)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((position.direction == "long" ? KryptonColor.green : KryptonColor.red).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .frame(width: 60, alignment: .center)

            VStack(alignment: .trailing, spacing: 0) {
                Text(String(format: "%+.2f", position.pnl))
                    .font(PulseFonts.tabular)
                    .foregroundStyle(position.pnl >= 0 ? KryptonColor.green : KryptonColor.red)
                    .fontWeight(.bold)
                Text(String(format: "%+.1f%%", position.pnlPercent))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            .frame(width: 140, alignment: .trailing)

            Text(recommendationLabel)
                .font(PulseFonts.micro)
                .foregroundStyle(recommendationColor)
                .fontWeight(.bold)
                .padding(.horizontal, PulseSpacing.xs).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: PulseRadii.badge).fill(recommendationColor.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.badge).stroke(recommendationColor.opacity(0.15), lineWidth: 1))
                .frame(width: 110, alignment: .center)

            KryptonRiskBadge(level: KryptonRiskBadge.Level(fromRiskLevel: position.riskLevel), showLabel: true)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, PulseSpacing.sm)
        .padding(.horizontal, PulseSpacing.sm)
        .background(isHovered ? KryptonColor.surfaceHover : Color.clear)
    }

    private var recommendationLabel: String {
        switch position.aiRecommendation {
        case "hold": return "HOLD 持有"
        case "reduce": return "REDUCE 减仓"
        case "take-profit": return "PROFIT 止盈"
        case "close": return "CLOSE 平仓"
        default: return position.aiRecommendation.uppercased()
        }
    }

    private var recommendationColor: Color {
        switch position.aiRecommendation {
        case "hold": return PulseColors.accent
        case "reduce": return KryptonColor.amber
        case "take-profit": return PulseColors.cyan
        case "close": return KryptonColor.red
        default: return colors.textSecondary
        }
    }

}
