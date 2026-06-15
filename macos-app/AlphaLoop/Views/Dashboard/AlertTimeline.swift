// AlertTimeline.swift — Alert Timeline for Dashboard Bento Grid
// Vertical timeline of system alerts with level-colored dots and connector lines.

import SwiftUI

struct AlertTimeline: View {
    @Environment(PulseColors.self) private var colors

    let alerts: [AlertResponse]

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Label
                TerminalLabel(text: L10n.Dashboard.alertTimeline)

                if alerts.isEmpty {
                    EmptyStateView(
                        icon: "bell.badge",
                        title: L10n.Dashboard.alertTimeline,
                        description: ""
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(alerts.enumerated()), id: \.offset) { index, alert in
                                alertRow(alert, index: index, isLast: index == alerts.count - 1)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
            }
        }
    }

    // MARK: - Alert Row

    private func alertRow(_ alert: AlertResponse, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Timeline column: dot + connector line
            VStack(spacing: 0) {
                Circle()
                    .fill(levelColor(alert.level))
                    .frame(width: 10, height: 10)
                    .shadow(color: levelColor(alert.level).opacity(0.4), radius: 3)

                if !isLast {
                    Rectangle()
                        .fill(colors.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)

                // Meta: symbol + time
                HStack(spacing: PulseSpacing.xxs) {
                    if !alert.symbol.isEmpty {
                        Text(alert.symbol)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                    if let time = alert.time {
                        Text(time)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
            .padding(.bottom, PulseSpacing.sm)

            Spacer()
        }
    }

    // MARK: - Level Color

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "error": return PulseColors.StateColors.red
        case "warning": return PulseColors.StateColors.amber
        default: return PulseColors.cyan
        }
    }
}
