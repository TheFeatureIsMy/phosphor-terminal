// GlobalRiskCard.swift — Global risk state card
// Status pill + daily/weekly loss gauge bars + reason chips

import SwiftUI

struct GlobalRiskCard: View {
    @Environment(PulseColors.self) private var colors
    let risk: RiskOverviewResponse

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.globalRiskState)

                // Status pill
                KryptonStatusPill(
                    label: L10n.Dashboard.globalRiskState,
                    value: stateDisplayValue,
                    state: stateColor
                )

                // Gauge bars
                VStack(spacing: PulseSpacing.xs) {
                    gaugeBar(
                        label: L10n.Dashboard.dailyLoss,
                        value: risk.dailyLossRemainingPct
                    )

                    gaugeBar(
                        label: L10n.Dashboard.weeklyLoss,
                        value: risk.weeklyLossRemainingPct
                    )
                }

                // Reason chips
                if !risk.reasonCodes.isEmpty {
                    HStack(spacing: PulseSpacing.xxs) {
                        ForEach(risk.reasonCodes, id: \.self) { code in
                            reasonChip(code)
                        }
                    }
                }

                // Emergency locked banner
                if risk.emergencyLocked {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text(L10n.Dashboard.emergencyLocked)
                            .font(PulseFonts.micro)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(PulseColors.danger)
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, PulseSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(PulseColors.danger.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke(PulseColors.danger.opacity(0.25), lineWidth: 1)
                    )
                }
            }
            .frame(minHeight: 140)
        }
    }

    // MARK: - Gauge Bar

    private func gaugeBar(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)

                Spacer()

                Text(String(format: "%.0f%%", value * 100))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(gaugeColor(for: value))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.surface)
                        .frame(height: 4)

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(gaugeColor(for: value))
                        .frame(
                            width: max(0, geometry.size.width * min(1.0, value)),
                            height: 4
                        )
                        .shadow(color: gaugeColor(for: value).opacity(0.3), radius: 3)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Reason Chip

    private func reasonChip(_ code: String) -> some View {
        Text(code)
            .font(PulseFonts.micro)
            .foregroundStyle(PulseColors.cyan)
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(PulseColors.cyan.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(PulseColors.cyan.opacity(0.2), lineWidth: 1)
            )
    }

    // MARK: - Computed Properties

    private var stateDisplayValue: String {
        if risk.emergencyLocked {
            return L10n.Dashboard.emergencyLocked
        }
        switch risk.globalState.lowercased() {
        case "normal", "healthy":
            return L10n.Dashboard.normal
        case "warning":
            return L10n.Dashboard.warning
        case "blocked":
            return L10n.Dashboard.blocked
        case "locked":
            return L10n.Dashboard.locked
        default:
            return risk.globalState.uppercased()
        }
    }

    private var stateColor: Color {
        if risk.emergencyLocked {
            return PulseColors.danger
        }
        switch risk.globalState.lowercased() {
        case "normal", "healthy":
            return KryptonColor.green
        case "warning":
            return KryptonColor.amber
        case "blocked", "locked":
            return KryptonColor.red
        default:
            return KryptonColor.gray
        }
    }

    private func gaugeColor(for value: Double) -> Color {
        value > 0.4 ? PulseColors.accent : PulseColors.amber
    }
}
