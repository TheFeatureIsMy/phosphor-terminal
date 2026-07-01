// EquityCurveHero.swift — 360pt 主视觉 equity curve + compare 叠加

import SwiftUI

struct EquityCurveHero: View {
    let run: BacktestRunV2
    let comparedRuns: [BacktestRunV2]
    let compareMode: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Text(L10n.zh("权益曲线", en: "Equity Curve"))
                    .font(PulseFonts.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                if compareMode && !comparedRuns.isEmpty {
                    HStack(spacing: PulseSpacing.sm) {
                        ForEach(comparedRuns) { r in
                            HStack(spacing: 4) {
                                Circle().fill(seriesColor(for: r.id)).frame(width: 8, height: 8)
                                Text("#\(r.id)").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                            }
                        }
                    }
                }
            }

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .fill(colors.surfaceHover.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))

                    if compareMode && !comparedRuns.isEmpty {
                        ForEach(comparedRuns) { r in
                            equityPath(for: r.equityCurve, in: geo.size, color: seriesColor(for: r.id))
                        }
                    } else {
                        equityPath(for: run.equityCurve, in: geo.size, color: PulseColors.accent, fill: true)
                    }
                }
            }
            .frame(height: 300)

            HStack(spacing: PulseSpacing.lg) {
                metricLabel(L10n.zh("总收益", en: "Total Return"), value: run.totalReturn, isPositive: run.totalReturn >= 0)
                metricLabel(L10n.zh("最大回撤", en: "Max Drawdown"), value: run.maxDrawdown, isPositive: false)
                if let peak = run.equityCurve.max(by: { $0.equity < $1.equity }) {
                    metricLabel(L10n.zh("峰值", en: "Peak"), value: peak.equity, isPositive: true)
                }
            }
            .font(PulseFonts.micro)
        }
    }

    private func equityPath(for points: [BacktestEquityPoint], in size: CGSize, color: Color, fill: Bool = false) -> some View {
        guard points.count >= 2 else { return AnyView(EmptyView()) }
        let values = points.map { $0.equity }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(maxV - minV, 1)
        let stepX = size.width / CGFloat(points.count - 1)
        let path = Path { p in
            for (idx, pt) in points.enumerated() {
                let x = CGFloat(idx) * stepX
                let y = size.height - CGFloat((pt.equity - minV) / range) * size.height
                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
        let fillPath = Path { p in
            p.move(to: CGPoint(x: 0, y: size.height))
            for (idx, pt) in points.enumerated() {
                let x = CGFloat(idx) * stepX
                let y = size.height - CGFloat((pt.equity - minV) / range) * size.height
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
        }
        return AnyView(
            ZStack {
                if fill {
                    fillPath.fill(LinearGradient(colors: [color.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                }
                path.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        )
    }

    private func seriesColor(for id: Int) -> Color {
        let palette: [Color] = [PulseColors.accent, PulseColors.cyan, PulseColors.purple, PulseColors.amber]
        return palette[abs(id) % palette.count]
    }

    private func metricLabel(_ label: String, value: Double, isPositive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(colors.textMuted)
            Text(String(format: "%+.2f%%", value * 100))
                .foregroundStyle(isPositive ? PulseColors.accent : PulseColors.danger)
        }
    }
}
