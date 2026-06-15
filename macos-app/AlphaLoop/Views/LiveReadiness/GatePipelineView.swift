// GatePipelineView.swift — Horizontal gate corridor

import SwiftUI

struct GatePipelineView: View {
    @Environment(PulseColors.self) private var colors
    let gates: [StrategyGate]

    private var passedCount: Int { gates.filter(\.passed).count }
    private var allPassed: Bool { passedCount == gates.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(colors.border.opacity(0.3))
            gateStrip
            failedGateDetails
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border.opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            TerminalLabel(text: L10n.LiveReadiness.strategyGates)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(allPassed ? PulseColors.accent : colors.textMuted)
                    .frame(width: 5, height: 5)
                    .shadow(color: allPassed ? PulseColors.accent.opacity(0.5) : .clear, radius: 3)
                Text(L10n.LiveReadiness.gateCount(passedCount, gates.count))
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(allPassed ? PulseColors.accent : colors.textSecondary)
            }
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.sm)
    }

    // MARK: - Gate Strip

    private var gateStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(gates.enumerated()), id: \.element.id) { index, gate in
                gateCell(gate: gate, seq: index + 1)

                if index < gates.count - 1 {
                    Rectangle()
                        .fill(colors.border.opacity(0.15))
                        .frame(width: 0.5)
                }
            }
        }
    }

    private func gateCell(gate: StrategyGate, seq: Int) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            // Top status bar
            Rectangle()
                .fill(gate.passed ? PulseColors.accent : PulseColors.danger)
                .frame(height: 2)
                .shadow(color: (gate.passed ? PulseColors.accent : PulseColors.danger).opacity(0.3), radius: 3, y: 1)

            // Sequence number
            Text(String(format: "%02d", seq))
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundStyle(gate.passed ? PulseColors.accent : PulseColors.danger)

            // Gate name
            Text(gate.shortLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(colors.textSecondary)
                .lineLimit(1)

            // Verdict badge
            Text(gate.passed ? L10n.LiveReadiness.go : L10n.LiveReadiness.noGo)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(gate.passed ? PulseColors.accent : PulseColors.danger)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill((gate.passed ? PulseColors.accent : PulseColors.danger).opacity(0.08))
                )

            Spacer().frame(height: PulseSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .background(gate.passed ? Color.clear : PulseColors.danger.opacity(0.02))
    }

    // MARK: - Failed Gate Details

    @ViewBuilder
    private var failedGateDetails: some View {
        let failed = gates.filter { !$0.passed }
        if !failed.isEmpty {
            Divider().background(colors.border.opacity(0.2))

            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                ForEach(failed, id: \.id) { gate in
                    HStack(spacing: PulseSpacing.xs) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(PulseColors.danger)
                            .frame(width: 12)

                        Text(gate.shortLabel)
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(PulseColors.danger)

                        Text("— \(gate.remedy)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.sm)
            .background(PulseColors.danger.opacity(0.02))
        }
    }
}
