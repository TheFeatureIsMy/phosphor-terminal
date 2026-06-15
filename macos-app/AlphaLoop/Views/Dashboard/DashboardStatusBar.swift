// DashboardStatusBar.swift — Infrastructure-only status bar
// SYS / FREQTRADE / REDIS / EXCHANGE status cells + reason chips

import SwiftUI

struct DashboardStatusBar: View {
    @Environment(PulseColors.self) private var colors
    let system: SystemOverviewResponse
    let reasonCodes: [String]

    var body: some View {
        HStack(spacing: 0) {
            // SYS cell
            statusCell(
                label: L10n.Dashboard.systemState,
                value: sysDisplayValue,
                dot: sysDotColor
            )

            cellDivider

            // FREQTRADE cell
            statusCell(
                label: L10n.Dashboard.freqtrade,
                value: "\(system.fastTrackLatencyMs)ms",
                dot: system.fastTrackLatencyMs < 100
                    ? KryptonColor.green : KryptonColor.amber
            )

            cellDivider

            // REDIS cell
            statusCell(
                label: L10n.Dashboard.redis,
                value: "\(system.redisRttMs)ms",
                dot: system.redisRttMs < 50
                    ? KryptonColor.green : KryptonColor.amber
            )

            cellDivider

            // EXCHANGE cell
            statusCell(
                label: L10n.Dashboard.exchange,
                value: system.exchangeState.uppercased(),
                dot: exchangeDotColor
            )

            Spacer(minLength: PulseSpacing.md)

            // Reason chips
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
    }

    // MARK: - Status Cell

    private func statusCell(label: String, value: String, dot: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
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

    // MARK: - Divider

    private var cellDivider: some View {
        Rectangle()
            .fill(colors.border)
            .frame(width: 1, height: 14)
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

    // MARK: - Computed Colors

    private var sysDisplayValue: String {
        switch system.liveReadinessState.lowercased() {
        case "live_ready", "live_small_ready":
            return "OK"
        case "paper_only":
            return "PAPER"
        case "not_ready":
            return "DOWN"
        default:
            return system.liveReadinessState.uppercased()
        }
    }

    private var sysDotColor: Color {
        switch system.liveReadinessState.lowercased() {
        case "live_ready", "live_small_ready":
            return KryptonColor.green
        case "paper_only":
            return KryptonColor.amber
        default:
            return KryptonColor.red
        }
    }

    private var exchangeDotColor: Color {
        switch system.exchangeState.lowercased() {
        case "ok", "healthy", "running":
            return KryptonColor.green
        case "degraded", "warning":
            return KryptonColor.amber
        default:
            return KryptonColor.red
        }
    }
}
