// LiveReadinessCard.swift — Live readiness lamp + checks (real data only).
// Reads checks from `/api/overview/live-readiness`. Never fabricates chips.

import SwiftUI

struct LiveReadinessCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let system: SystemOverviewResponse?
    let readiness: LiveReadinessResponse?
    let dataSourceAvailable: Bool

    @State private var isPulsing = false

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.liveReadiness)

                HStack(spacing: 14) {
                    lamp
                    textBlock
                }

                if !dataSourceAvailable {
                    EmptyStateView(
                        icon: "antenna.radiowaves.left.and.right.slash",
                        title: L10n.Dashboard.dataSourceUnavailable,
                        description: ""
                    )
                    .frame(minHeight: 80)
                } else if checks.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.shield",
                        title: L10n.Dashboard.readinessNoData,
                        description: ""
                    )
                    .frame(minHeight: 80)
                } else {
                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text(L10n.Dashboard.liveReadinessChecks)
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ForEach(checks, id: \.key) { check in
                            checkRow(check)
                        }
                    }
                }
            }
            .frame(minHeight: 160)
        }
        .id(settingsState.language)
    }

    // MARK: - Lamp

    private var lamp: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [lampColor.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)

            Circle()
                .fill(lampColor.opacity(0.18))
                .frame(width: 28, height: 28)
                .scaleEffect(isPulsing ? 1.7 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [lampColor, lampColor.opacity(0.6), lampColor.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 14
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: lampColor.opacity(0.4), radius: 12)
                .shadow(color: lampColor.opacity(0.12), radius: 24)
        }
        .frame(width: 44, height: 44)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stateLabel)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(lampColor)
                .tracking(0.5)

            if let score = readiness?.score, score > 0 {
                Text("score \(score) · \(L10n.Dashboard.gatesPassed(checks.count))")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            } else {
                Text(L10n.Dashboard.gatesPassed(checks.count))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    // MARK: - Check Row

    private func checkRow(_ check: ReadinessCheckResponse) -> some View {
        let tone = checkTone(check.status)
        return HStack(spacing: 6) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
                .shadow(color: tone.color.opacity(0.4), radius: 2)
            Text(check.label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textSecondary)
                .textCase(.uppercase)
            Spacer()
            Text(check.value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
            if !check.threshold.isEmpty {
                Text("· \(check.threshold)")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    // MARK: - Derived

    private var checks: [ReadinessCheckResponse] {
        readiness?.checks ?? []
    }

    private var lampColor: Color {
        guard let state = system?.liveReadinessState.lowercased() else { return PulseColors.danger }
        switch state {
        case "live_ready", "live_small_ready", "live_full_ready", "live_running":
            return PulseColors.accent
        case "paper_only":
            return PulseColors.amber
        case "risk_locked", "emergency_locked":
            return PulseColors.danger
        default:
            return PulseColors.danger
        }
    }

    private var stateLabel: String {
        guard let state = system?.liveReadinessState.lowercased() else { return L10n.Dashboard.notReady }
        switch state {
        case "live_ready", "live_small_ready", "live_full_ready", "live_running":
            return L10n.Dashboard.liveReady
        case "paper_only":
            return L10n.Dashboard.paperOnly
        case "risk_locked":
            return L10n.Dashboard.riskLocked
        case "emergency_locked":
            return L10n.Dashboard.emergencyLocked
        default:
            return L10n.Dashboard.notReady
        }
    }

    private func checkTone(_ status: String) -> (color: Color, label: String) {
        switch status.lowercased() {
        case "healthy", "ok", "pass", "running":
            return (PulseColors.StateColors.green, "OK")
        case "warning", "degraded":
            return (PulseColors.StateColors.amber, "WARN")
        case "failed", "error", "down":
            return (PulseColors.StateColors.red, "FAIL")
        default:
            return (colors.textMuted, status.uppercased())
        }
    }
}
