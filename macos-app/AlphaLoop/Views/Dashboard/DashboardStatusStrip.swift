// DashboardStatusStrip.swift — Two-row status strip for the top bar.
// Row 1: brand + mode pill + main actions (in GlobalStatusBar; not in this file)
// Row 2: this strip — a single horizontal row of small glass status dots that
// summarize the system state (provider health, exchange, redis, freqtrade, risk,
// open positions, last update).

import SwiftUI

struct DashboardStatusStrip: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let system: SystemOverviewResponse?
    let risk: RiskOverviewResponse?
    let providerHealth: ProviderHealthSummary?
    let positions: [PositionData]
    let lastUpdated: Date?

    var body: some View {
        HStack(spacing: PulseSpacing.xs) {
            chip(
                label: L10n.Dashboard.providers,
                value: providerHealth.map { "\($0.healthy)/\($0.total)" } ?? "—",
                tone: providerTone
            )
            chip(
                label: L10n.Dashboard.exchange,
                value: system?.exchangeState.uppercased() ?? "—",
                tone: exchangeTone
            )
            chip(
                label: L10n.Dashboard.redis,
                value: redisValue,
                tone: redisTone
            )
            chip(
                label: L10n.Dashboard.freqtrade,
                value: freqtradeValue,
                tone: freqtradeTone
            )
            chip(
                label: L10n.Dashboard.risk,
                value: riskValue,
                tone: riskTone
            )
            chip(
                label: L10n.Dashboard.positions,
                value: "\(positions.count)",
                tone: positions.isEmpty ? .neutral : .live
            )
            if let lastUpdated {
                Spacer(minLength: PulseSpacing.xs)
                Text("\(L10n.Dashboard.lastUpdate) \(Self.timeFormatter.string(from: lastUpdated))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .id(settingsState.language)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border.opacity(0.6), lineWidth: 0.5)
        )
        .id(settingsState.language)
    }

    // MARK: - Chip

    private enum ChipTone { case live, warn, error, neutral }

    private func chip(label: String, value: String, tone: ChipTone) -> some View {
        let color: Color
        switch tone {
        case .live: color = PulseColors.StateColors.green
        case .warn: color = PulseColors.StateColors.amber
        case .error: color = PulseColors.StateColors.red
        case .neutral: color = colors.textMuted
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.4), radius: 2)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - Computed values (all derived from real data; "—" when null)

    private var redisValue: String {
        guard let rtt = system?.redisRttMs, rtt >= 0 else { return "—" }
        return "\(rtt)ms"
    }

    private var freqtradeValue: String {
        guard let state = system?.freqtradeState, state != "unknown" else { return "—" }
        return state.uppercased()
    }

    private var riskValue: String {
        guard let risk else { return "—" }
        return risk.emergencyLocked ? "LOCKED" : risk.globalState.uppercased()
    }

    // MARK: - Tones

    private var providerTone: ChipTone {
        guard let p = providerHealth, p.total > 0 else { return .neutral }
        if p.error > 0 { return .error }
        if p.warning > 0 { return .warn }
        return .live
    }

    private var exchangeTone: ChipTone {
        guard let s = system?.exchangeState.lowercased() else { return .neutral }
        switch s {
        case "ok", "healthy", "running": return .live
        case "degraded", "warning": return .warn
        case "down", "error", "unavailable": return .error
        default: return .neutral
        }
    }

    private var redisTone: ChipTone {
        guard let rtt = system?.redisRttMs, rtt >= 0 else { return .neutral }
        return rtt < 50 ? .live : (rtt < 200 ? .warn : .error)
    }

    private var freqtradeTone: ChipTone {
        guard let s = system?.freqtradeState.lowercased() else { return .neutral }
        switch s {
        case "healthy", "running", "ok": return .live
        case "degraded", "warning": return .warn
        case "down", "error", "unavailable", "stopped": return .error
        default: return .neutral
        }
    }

    private var riskTone: ChipTone {
        guard let risk else { return .neutral }
        if risk.emergencyLocked { return .error }
        switch risk.globalState.lowercased() {
        case "normal", "healthy": return .live
        case "warning": return .warn
        case "blocked", "locked": return .error
        default: return .neutral
        }
    }

    // MARK: - Formatter

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
