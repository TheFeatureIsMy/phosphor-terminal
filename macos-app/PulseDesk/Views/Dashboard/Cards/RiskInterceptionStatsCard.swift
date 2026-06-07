// RiskInterceptionStatsCard.swift — Bento 卡片: 风控拦截统计 (圆环仪表)
import SwiftUI

struct RiskInterceptionStatsCard: View {
    @Environment(PulseColors.self) private var colors
    let summary: RiskInterceptionSummary

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "风控拦截统计")

                let total = summary.rejected + summary.reduced + summary.paperOnly + summary.allowed

                HStack(spacing: PulseSpacing.md) {
                    ZStack {
                        Circle()
                            .stroke(colors.border, lineWidth: 8)
                            .frame(width: 80, height: 80)

                        dialSegment(total: total, count: summary.rejected, color: KryptonColor.red, startAngle: 0)
                        dialSegment(total: total, count: summary.reduced, color: KryptonColor.amber, startAngle: Double(summary.rejected) / Double(max(total, 1)) * 360)
                        dialSegment(total: total, count: summary.paperOnly, color: PulseColors.cyan, startAngle: Double(summary.rejected + summary.reduced) / Double(max(total, 1)) * 360)
                        dialSegment(total: total, count: summary.allowed, color: KryptonColor.green, startAngle: Double(summary.rejected + summary.reduced + summary.paperOnly) / Double(max(total, 1)) * 360)

                        VStack(spacing: 0) {
                            Text("\(total)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(colors.textPrimary)
                            Text("拦截/放行")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                    .frame(width: 90, height: 90)

                    VStack(alignment: .leading, spacing: 4) {
                        legendRow(label: "已拒绝", count: summary.rejected, color: KryptonColor.red, total: total)
                        legendRow(label: "已减仓", count: summary.reduced, color: KryptonColor.amber, total: total)
                        legendRow(label: "仅模拟", count: summary.paperOnly, color: PulseColors.cyan, total: total)
                        legendRow(label: "已放行", count: summary.allowed, color: KryptonColor.green, total: total)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .hoverEffect()
    }

    @ViewBuilder
    private func dialSegment(total: Int, count: Int, color: Color, startAngle: Double) -> some View {
        let pct = Double(count) / Double(max(total, 1))
        if pct > 0 {
            Circle()
                .trim(from: 0, to: CGFloat(pct))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.8), color], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90 + startAngle))
                .frame(width: 80, height: 80)
                .shadow(color: color.opacity(0.3), radius: 3)
        }
    }

    private func legendRow(label: String, count: Int, color: Color, total: Int) -> some View {
        let pct = total > 0 ? (Double(count) / Double(total)) * 100 : 0
        return HStack(spacing: PulseSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
                .frame(width: 40, alignment: .leading)
            Spacer()
            Text("\(count)")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
                .fontWeight(.bold)
            Text(String(format: "%.0f%%", pct))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
