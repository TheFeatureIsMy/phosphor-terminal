// ProviderHealthCard.swift — Aggregated provider health card.
// Driven by /api/admin/providers (summary) and shows total/healthy/warn/error
// plus a per-category breakdown. Empty-state when no providers configured.

import SwiftUI

struct ProviderHealthCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let summary: ProviderHealthSummary?
    let dataSourceAvailable: Bool

    @State private var expanded = false

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
                    if !summary.entries.isEmpty {
                        Button {
                            withAnimation(PulseAnimation.easeOutFast) { expanded.toggle() }
                        } label: {
                            Text(expanded ? L10n.Dashboard.collapsePanel : L10n.Dashboard.expandPanel)
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                        .buttonStyle(.plain)

                        if expanded {
                            entriesList(summary)
                        }
                    }
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
                Text("\(summary.healthy)/\(summary.total)")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.StateColors.green)
            }
        }
    }

    private func summaryRow(_ s: ProviderHealthSummary) -> some View {
        let text = L10n.Dashboard.providerSummary(s.total, s.healthy, s.warning, s.error)
        return Text(text)
            .font(PulseFonts.caption)
            .foregroundStyle(colors.textSecondary)
    }

    private func entriesList(_ s: ProviderHealthSummary) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            ForEach(s.entries) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: ProviderHealthEntry) -> some View {
        let tone = entryTone(entry)
        return HStack(spacing: PulseSpacing.xs) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
                .shadow(color: tone.color.opacity(0.4), radius: 2)
            Text(entry.providerName)
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)
            Text(L10n.Dashboard.providerCategory(entry.category))
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
            Spacer()
            if let latency = entry.latencyMs {
                Text("\(latency)ms")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            } else if let err = entry.lastError {
                Text(err)
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.warning)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, PulseSpacing.xxs)
    }

    private func entryTone(_ e: ProviderHealthEntry) -> (color: Color, label: String) {
        let lower = e.status.lowercased()
        switch lower {
        case "active", "healthy", "ok", "running":
            return (PulseColors.StateColors.green, L10n.Dashboard.providerStatusOk)
        case "warning", "degraded":
            return (PulseColors.StateColors.amber, L10n.Dashboard.providerStatusWarn)
        case "error", "failed", "down", "unavailable":
            return (PulseColors.StateColors.red, L10n.Dashboard.providerStatusError)
        default:
            return (colors.textMuted, e.status.uppercased())
        }
    }
}
