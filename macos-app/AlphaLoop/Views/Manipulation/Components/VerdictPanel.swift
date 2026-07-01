// VerdictPanel.swift — §1 判定面板：M-type + 风险等级 + 阶段 + 置信度环 + 数据完整度

import SwiftUI

struct VerdictPanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var availableLayers: Int {
        guard let layers = detail.evidenceLayers else { return 0 }
        return layers.values.filter { $0.available }.count
    }
    private var totalLayers: Int { detail.evidenceLayers?.count ?? 5 }
    private var confidenceCap: Double { detail.maxConfidence > 0 ? detail.maxConfidence : 1.0 }

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.verdict)
                HStack(alignment: .top, spacing: PulseSpacing.xl) {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("\(L10n.Manipulation.likely) \(detail.manipulationType)")
                            .font(PulseFonts.displayHeading)
                        Text("\(L10n.Manipulation.evidenceConsistentWith) \(detail.lifecycleStage)")
                            .font(PulseFonts.displaySubheading)
                            .foregroundStyle(colors.textMuted)
                        if !detail.riskLevel.isEmpty {
                            RiskBadge(level: detail.riskLevel)
                        }
                    }
                    Spacer()
                    ConfidenceRing(value: detail.confidence, cap: confidenceCap)
                        .frame(width: 96, height: 96)
                }
                HStack(spacing: PulseSpacing.md) {
                    Label("\(L10n.Manipulation.dataCompleteness): \(availableLayers)/\(totalLayers)", systemImage: "chart.bar.doc.horizontal")
                        .font(PulseFonts.caption)
                    if detail.maxConfidence > 0 {
                        Text("\(L10n.Manipulation.maxConfidence): \(Int(detail.maxConfidence * 100))%")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct ConfidenceRing: View {
    let value: Double
    let cap: Double
    @Environment(PulseColors.self) private var colors

    var body: some View {
        ZStack {
            Circle().stroke(colors.border, lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(value / cap, 1.0))
                .stroke(PulseColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(value * 100))%").font(PulseFonts.tabular)
                Text("cap \(Int(cap * 100))%").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
    }
}

private struct RiskBadge: View {
    let level: String
    @Environment(PulseColors.self) private var colors
    var body: some View {
        Text(level.uppercased())
            .font(PulseFonts.micro)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(level == "critical" || level == "high" ? PulseColors.danger.opacity(0.2) : PulseColors.amber.opacity(0.2))
            }
    }
}
