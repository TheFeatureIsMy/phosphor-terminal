// ManipulationAlertFeed.swift — 操纵告警流
// Scrollable alert timeline inside KryptonCard(.subtle): severity dot, title, time, alert type badge

import SwiftUI

struct ManipulationAlertFeed: View {
    @Environment(PulseColors.self) private var colors

    let alerts: [ManipulationAlertItem]

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Terminal-style section label
                TerminalLabel(text: L10n.Manipulation.alertFeed)

                if alerts.isEmpty {
                    EmptyStateView(
                        icon: "bell.badge",
                        title: L10n.Manipulation.alertFeed,
                        description: ""
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                                alertRow(alert, isLast: index == alerts.count - 1)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }

    // MARK: - Alert Row

    private func alertRow(_ alert: ManipulationAlertItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Timeline column: severity dot + vertical connector line
            VStack(spacing: 0) {
                Circle()
                    .fill(severityColor(alert.severity))
                    .frame(width: 10, height: 10)
                    .shadow(color: severityColor(alert.severity).opacity(0.4), radius: 3)

                if !isLast {
                    Rectangle()
                        .fill(colors.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            // Content column
            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(alert.title)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)

                // Meta row: time + alert type badge
                HStack(spacing: PulseSpacing.xs) {
                    Text(formattedTime(alert.createdAt))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)

                    alertTypeBadge(alert.alertType)
                }
            }
            .padding(.bottom, PulseSpacing.sm)

            Spacer()
        }
    }

    // MARK: - Alert Type Badge

    private func alertTypeBadge(_ alertType: String) -> some View {
        let (label, color) = alertTypeInfo(alertType)
        return Text(label)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
    }

    private func alertTypeInfo(_ alertType: String) -> (String, Color) {
        switch alertType.lowercased() {
        case "stage_change":
            return (L10n.Manipulation.alertStageChange, PulseColors.cyan)
        case "new_case":
            return (L10n.Manipulation.alertNewCase, PulseColors.accent)
        case "confidence_spike":
            return (L10n.Manipulation.alertConfidenceSpike, PulseColors.danger)
        case "signal_change":
            return (L10n.Manipulation.alertSignalChange, PulseColors.warning)
        default:
            return (alertType.uppercased(), colors.textMuted)
        }
    }

    // MARK: - Severity Color

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "critical": return PulseColors.danger
        case "warning":  return PulseColors.amber
        case "info":     return PulseColors.cyan
        default:         return colors.textMuted
        }
    }

    // MARK: - Time Formatter

    private func formattedTime(_ isoString: String) -> String {
        // Extract HH:mm from ISO timestamp (e.g. "2026-06-15T12:00:00Z" → "12:00")
        guard isoString.count >= 16 else { return isoString }
        let start = isoString.index(isoString.startIndex, offsetBy: 11)
        let end = isoString.index(start, offsetBy: 5)
        return String(isoString[start..<end])
    }
}
