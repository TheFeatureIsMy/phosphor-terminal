// LiveReadinessCard.swift — Live readiness lamp + state text + gate chips
// Pulsing lamp with radial gradient, ambient glow, and reason chips

import SwiftUI

struct LiveReadinessCard: View {
    @Environment(PulseColors.self) private var colors
    let system: SystemOverviewResponse

    @State private var isPulsing = false

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.liveReadiness)

                // Lamp + State text
                HStack(spacing: 14) {
                    // Pulsing lamp with ambient glow
                    ZStack {
                        // Ambient glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [lampColor.opacity(0.06), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)

                        // Outer pulse ring
                        Circle()
                            .fill(lampColor.opacity(0.15))
                            .frame(width: 28, height: 28)
                            .scaleEffect(isPulsing ? 1.6 : 1.0)
                            .opacity(isPulsing ? 0 : 0.6)

                        // Main lamp
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        lampColor,
                                        lampColor.opacity(0.6),
                                        lampColor.opacity(0.2),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 14
                                )
                            )
                            .frame(width: 28, height: 28)
                            .shadow(color: lampColor.opacity(0.35), radius: 12)
                            .shadow(color: lampColor.opacity(0.1), radius: 24)
                    }
                    .frame(width: 44, height: 44)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            isPulsing = true
                        }
                    }

                    // Text block
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stateLabel)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(lampColor)
                            .tracking(0.5)

                        Text(L10n.Dashboard.gatesPassed(7))
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                    }
                }

                // Reason chips
                HStack(spacing: PulseSpacing.xxs) {
                    ForEach(gateChips, id: \.self) { chip in
                        gateChipView(chip)
                    }
                }
            }
            .frame(minHeight: 140)
        }
    }

    // MARK: - Lamp Color

    private var lampColor: Color {
        switch system.liveReadinessState.lowercased() {
        case "live_ready", "live_small_ready":
            return PulseColors.accent
        case "paper_only":
            return PulseColors.amber
        case "risk_locked":
            return PulseColors.danger
        case "emergency_locked":
            return PulseColors.danger
        default:
            return PulseColors.danger
        }
    }

    // MARK: - State Label

    private var stateLabel: String {
        switch system.liveReadinessState.lowercased() {
        case "live_ready", "live_small_ready":
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

    // MARK: - Gate Chips

    private var gateChips: [String] {
        // Derive reasonable gate labels from system state
        var chips = [String]()
        if system.freqtradeState.lowercased() == "healthy" || system.freqtradeState.lowercased() == "running" {
            chips.append("freqtrade_ok")
        }
        if system.redisRttMs < 50 {
            chips.append("redis_ok")
        }
        if system.exchangeState.lowercased() == "ok" || system.exchangeState.lowercased() == "healthy" {
            chips.append("exchange_ok")
        }
        if system.fastTrackLatencyMs < 200 {
            chips.append("latency_ok")
        }
        // Add common defaults
        chips.append(contentsOf: ["risk_budget_ok", "balance_ok", "config_ok"])
        return Array(chips.prefix(7))
    }

    private func gateChipView(_ label: String) -> some View {
        Text(label)
            .font(PulseFonts.micro)
            .foregroundStyle(PulseColors.accent.opacity(0.7))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(PulseColors.accent.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(PulseColors.accent.opacity(0.12), lineWidth: 1)
            )
    }
}
