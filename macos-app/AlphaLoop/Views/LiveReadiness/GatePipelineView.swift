// GatePipelineView.swift — Vertical gate timeline (editorial event-thread style)

import SwiftUI

struct GatePipelineView: View {
    @Environment(PulseColors.self) private var colors
    let gates: [StrategyGate]

    private var passedCount: Int { gates.filter(\.passed).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(gates.enumerated()), id: \.element.id) { index, gate in
                gateRow(gate: gate, seq: index + 1, isLast: index == gates.count - 1)
            }
        }
    }

    private func gateRow(gate: StrategyGate, seq: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            // Timeline column: dot + connector
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(gateColor(gate).opacity(0.18))
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(gateColor(gate))
                        .frame(width: 8, height: 8)
                        .shadow(color: gateColor(gate).opacity(0.6), radius: 4)
                }

                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [gateColor(gate).opacity(0.5), colors.textMuted.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1.5)
                        .frame(minHeight: 28)
                }
            }
            .frame(width: 18)

            // Content column
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%02d", seq))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(gateColor(gate))

                    Text(gate.shortLabel)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)

                    Spacer()

                    // Verdict badge
                    Text(gate.passed ? L10n.LiveReadiness.go : L10n.LiveReadiness.noGo)
                        .font(PulseFonts.micro)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(gateColor(gate))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.badge)
                                .fill(gateColor(gate).opacity(0.12))
                        )
                }

                if !gate.passed && !gate.remedy.isEmpty {
                    Text("\u{201C}\\(gate.remedy)\u{201D}")
                        .font(.system(size: 12.5, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, isLast ? 0 : PulseSpacing.sm)
        }
    }

    private func gateColor(_ gate: StrategyGate) -> Color {
        gate.passed ? PulseColors.accent : PulseColors.danger
    }
}
