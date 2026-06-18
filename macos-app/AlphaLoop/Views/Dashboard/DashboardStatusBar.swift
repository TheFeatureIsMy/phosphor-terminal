// DashboardStatusBar.swift — Compact infrastructure cell (within page body).
// For full system state, see `DashboardStatusStrip` (in the top bar).

import SwiftUI

struct DashboardStatusBar: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let system: SystemOverviewResponse?
    let reasonCodes: [String]

    var body: some View {
        HStack(spacing: 0) {
            statusCell(
                label: L10n.Dashboard.systemState,
                value: sysDisplayValue,
                dot: sysDotColor
            )
            cellDivider
            statusCell(
                label: L10n.Dashboard.freqtrade,
                value: freqtradeValue,
                dot: freqtradeDot
            )
            cellDivider
            statusCell(
                label: L10n.Dashboard.redis,
                value: redisValue,
                dot: redisDot
            )
            cellDivider
            statusCell(
                label: L10n.Dashboard.exchange,
                value: system?.exchangeState.uppercased() ?? "—",
                dot: exchangeDot
            )

            Spacer(minLength: PulseSpacing.md)

            if !reasonCodes.isEmpty {
                HStack(spacing: PulseSpacing.xxs) {
                    ForEach(reasonCodes, id: \.self) { code in
                        reasonChip(code)
                    }
                }
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .stroke(colors.border, lineWidth: 0.5)
        )
        .id(settingsState.language)
    }

    private func statusCell(label: String, value: String, dot: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
                .shadow(color: dot.opacity(0.5), radius: 3)
            Text(label)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.xxs)
    }

    private var cellDivider: some View {
        Rectangle().fill(colors.border).frame(width: 1, height: 14)
    }

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
                    .stroke(PulseColors.cyan.opacity(0.20), lineWidth: 0.5)
            )
    }

    // MARK: - Computed

    private var sysDisplayValue: String {
        guard let s = system?.liveReadinessState.lowercased() else { return "—" }
        switch s {
        case "live_ready", "live_small_ready", "live_full_ready": return "OK"
        case "paper_only": return "PAPER"
        case "not_ready": return "DOWN"
        default: return system?.liveReadinessState.uppercased() ?? "—"
        }
    }

    private var sysDotColor: Color {
        guard let s = system?.liveReadinessState.lowercased() else { return PulseColors.danger }
        switch s {
        case "live_ready", "live_small_ready", "live_full_ready": return PulseColors.StateColors.green
        case "paper_only": return PulseColors.StateColors.amber
        default: return PulseColors.StateColors.red
        }
    }

    private var freqtradeValue: String {
        guard let s = system?.freqtradeState, s != "unknown" else { return "—" }
        return s.uppercased()
    }

    private var freqtradeDot: Color {
        guard let s = system?.freqtradeState.lowercased() else { return colors.textMuted }
        switch s {
        case "healthy", "running", "ok": return PulseColors.StateColors.green
        case "warning", "degraded": return PulseColors.StateColors.amber
        case "down", "error", "unavailable", "stopped": return PulseColors.StateColors.red
        default: return colors.textMuted
        }
    }

    private var redisValue: String {
        guard let rtt = system?.redisRttMs, rtt >= 0 else { return "—" }
        return "\(rtt)ms"
    }

    private var redisDot: Color {
        guard let rtt = system?.redisRttMs, rtt >= 0 else { return colors.textMuted }
        return rtt < 50 ? PulseColors.StateColors.green : (rtt < 200 ? PulseColors.StateColors.amber : PulseColors.StateColors.red)
    }

    private var exchangeDot: Color {
        guard let s = system?.exchangeState.lowercased() else { return colors.textMuted }
        switch s {
        case "ok", "healthy", "running": return PulseColors.StateColors.green
        case "degraded", "warning": return PulseColors.StateColors.amber
        case "down", "error", "unavailable": return PulseColors.StateColors.red
        default: return colors.textMuted
        }
    }
}
