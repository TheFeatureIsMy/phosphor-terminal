// DualProfileSignalPanel.swift — §7 保守/激进双栏 + 影响交易对 + 策略联动 + 跳转

import SwiftUI

struct DualProfileSignalPanel: View {
    let detail: ManipulationCaseDetail
    let impact: StrategyImpactResponse?
    let onNavigate: (AppRoute) -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.defenseStrategyImpact)

                HStack(alignment: .top, spacing: PulseSpacing.md) {
                    ProfileColumn(
                        title: "CONSERVATIVE",
                        tint: PulseColors.info,
                        action: detail.tradingSignal.conservative.action,
                        rationale: detail.tradingSignal.conservative.rationale,
                        riskLevel: detail.riskLevel
                    )
                    ProfileColumn(
                        title: "AGGRESSIVE",
                        tint: PulseColors.amber,
                        action: detail.tradingSignal.aggressive.action,
                        rationale: detail.tradingSignal.aggressive.rationale,
                        riskLevel: detail.riskLevel
                    )
                }

                if let symbols = detail.affectedSymbols, !symbols.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        Text(L10n.Manipulation.affectedSymbols).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        FlowLayout(spacing: PulseSpacing.xs) {
                            ForEach(symbols, id: \.self) { s in
                                Text(s).font(PulseFonts.micro).padding(.horizontal, PulseSpacing.sm).padding(.vertical, 2)
                                    .background { Capsule().fill(colors.cardBackground) }
                            }
                        }
                    }
                }

                if let impact = impact, !impact.affectedStrategies.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text(L10n.Manipulation.strategyImpact).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        ForEach(impact.affectedStrategies) { s in
                            StrategyImpactRow(item: s) { onNavigate(.strategyWorkspace) }
                        }
                    }
                }

                Button {
                    onNavigate(.riskCenter)
                } label: {
                    Label(L10n.Manipulation.openStrategyRisk, systemImage: "arrow.right.circle")
                        .font(PulseFonts.tabular)
                }
                .buttonStyle(.bordered)
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct ProfileColumn: View {
    let title: String
    let tint: Color
    let action: String
    let rationale: String
    let riskLevel: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(title).font(PulseFonts.micro).foregroundStyle(tint)
            Text(action).font(PulseFonts.displaySubheading).foregroundStyle(tint)
            if !rationale.isEmpty {
                Text(rationale).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            }
            if !riskLevel.isEmpty {
                Text("●●●○ \(riskLevel.uppercased())").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: PulseRadii.md).fill(tint.opacity(0.08))
        }
    }
}

private struct StrategyImpactRow: View {
    let item: StrategyImpactItem
    let onEdit: () -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.strategyName).font(PulseFonts.tabular)
                if item.wouldBlock {
                    Label(L10n.Manipulation.wouldBlock, systemImage: "checkmark.shield")
                        .font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
                } else if item.reasonCodes.contains("filter_disabled") {
                    Label(L10n.Manipulation.filterDisabled, systemImage: "exclamationmark.triangle")
                        .font(PulseFonts.micro).foregroundStyle(PulseColors.amber)
                }
            }
            Spacer()
            Button(L10n.Manipulation.edit, action: onEdit)
                .font(PulseFonts.micro)
                .buttonStyle(.borderless)
        }
        .padding(PulseSpacing.sm)
        .background { RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.cardBackground) }
    }
}

/// Uses existing FlowLayout from ShadowStrategyDraftView
