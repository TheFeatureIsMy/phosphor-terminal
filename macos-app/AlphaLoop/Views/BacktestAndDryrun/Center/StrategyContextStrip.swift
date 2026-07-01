// StrategyContextStrip.swift — 折叠区：策略 + 风险 + 晋升门摘要

import SwiftUI

struct StrategyContextStrip: View {
    let run: BacktestRunV2
    @Binding var isExpanded: Bool
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { isExpanded.toggle() } label: {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                    Text(L10n.zh("策略 #\(run.strategyId) · 0 个警告 · 未就绪", en: "Strategy #\(run.strategyId) · 0 warnings · Not Ready"))
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                    Spacer()
                }
                .padding(PulseSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().overlay(colors.border)
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    Text(L10n.zh("策略 #", en: "Strategy #") + "\(run.strategyId)")
                        .font(PulseFonts.tabular)
                        .foregroundStyle(colors.textPrimary)
                    Text(L10n.zh("风险警告与晋升门状态在此展示。", en: "Risk warnings and promotion gate status shown here."))
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .padding(PulseSpacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.surfaceHover.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
        )
    }
}
