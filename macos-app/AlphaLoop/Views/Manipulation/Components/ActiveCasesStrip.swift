// ActiveCasesStrip.swift — §0 横向滚动的活跃 case 缩略卡

import SwiftUI

struct ActiveCasesStrip: View {
    let overview: ManipulationRadarOverview
    let focusedCaseId: String?
    let onSelect: (String) -> Void

    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.zh("活跃案例", en: "ACTIVE CASES"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PulseSpacing.md) {
                        ForEach(overview.activeCases) { c in
                            ActiveCaseCard(case_: c, isFocused: c.id == focusedCaseId)
                                .onTapGesture { onSelect(c.id) }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct ActiveCaseCard: View {
    let case_: ManipulationCaseSummary
    let isFocused: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xs) {
                Text(case_.symbol).font(PulseFonts.tabular)
                Text(case_.manipulationType).font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
            }
            HStack(spacing: PulseSpacing.xs) {
                Text(case_.lifecycleStage.uppercased()).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Text("·").foregroundStyle(colors.textMuted)
                Text("\(Int(case_.confidence * 100))%").font(PulseFonts.tabular).foregroundStyle(PulseColors.accent)
            }
        }
        .padding(PulseSpacing.md)
        .frame(width: 180, alignment: .leading)
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: PulseRadii.md).fill(PulseColors.accent.opacity(0.12))
            } else {
                RoundedRectangle(cornerRadius: PulseRadii.md).fill(colors.cardBackground)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .strokeBorder(isFocused ? PulseColors.accent : colors.border, lineWidth: isFocused ? 2 : 1)
        }
    }
}
