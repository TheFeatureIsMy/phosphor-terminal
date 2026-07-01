// SimilarCasesPanel.swift — §8 右半 相似历史案例 + outcome

import SwiftUI

struct SimilarCasesPanel: View {
    let similar: SimilarCasesResponse
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.similarHistoricalCases)
                VStack(spacing: PulseSpacing.md) {
                    ForEach(similar.similar) { c in
                        SimilarCaseRow(item: c)
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct SimilarCaseRow: View {
    let item: SimilarCaseItem
    @Environment(PulseColors.self) private var colors
    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xs) {
                    Text(item.symbol).font(PulseFonts.tabular)
                    Text(item.manipulationType).font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
                }
                Text(item.completedAt.prefix(10)).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("sim \(Int(item.similarity * 100))%").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                if let dd = item.outcome["realized_drawdown"] {
                    Text(String(format: "%+.1f%%", dd * 100)).font(PulseFonts.tabular)
                        .foregroundStyle(dd < 0 ? PulseColors.danger : PulseColors.accent)
                }
            }
        }
        .padding(PulseSpacing.sm)
        .background { RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.cardBackground) }
    }
}
