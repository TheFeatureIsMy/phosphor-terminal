// ProviderHealthCard.swift - Aggregated provider health card.

import SwiftUI

struct ProviderHealthCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let summary: ProviderHealthSummary?
    let dataSourceAvailable: Bool

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                header

                if !dataSourceAvailable || summary == nil {
                    EmptyStateView(
                        icon: "antenna.radiowaves.left.and.right.slash",
                        title: L10n.Dashboard.dataSourceUnavailable,
                        description: ""
                    )
                    .frame(minHeight: 100)
                } else if let summary, summary.total > 0 {
                    summaryRow(summary)
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: L10n.Dashboard.providerNoData,
                        description: ""
                    )
                    .frame(minHeight: 100)
                }
            }
        }
        .id(settingsState.language)
    }

    private var header: some View {
        HStack(spacing: PulseSpacing.xs) {
            TerminalLabel(text: L10n.Dashboard.providerHealth)
            Spacer()
            if let summary, dataSourceAvailable {
                Text("\(summary.totalActive)/\(summary.total)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.StateColors.green)
            }
        }
    }

    private func summaryRow(_ s: ProviderHealthSummary) -> some View {
        HStack(spacing: PulseSpacing.md) {
            statItem(label: L10n.zh("总数", en: "Total"), value: "\(s.total)", color: colors.textPrimary)
            statItem(label: L10n.zh("活跃", en: "Active"), value: "\(s.totalActive)", color: PulseColors.success)
            statItem(label: L10n.zh("异常", en: "Error"), value: "\(s.totalError)", color: PulseColors.danger)
            statItem(label: L10n.zh("已禁用", en: "Disabled"), value: "\(s.totalDisabled)", color: colors.textMuted)
            Spacer()
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
        }
    }
}
