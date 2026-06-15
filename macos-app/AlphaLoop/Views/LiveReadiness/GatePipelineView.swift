import SwiftUI

struct GatePipelineView: View {
    @Environment(PulseColors.self) private var colors
    let gates: [StrategyGate]

    private var passedCount: Int { gates.filter(\.passed).count }

    var body: some View {
        KryptonCard(emphasis: .subtle, cardPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    TerminalLabel(text: L10n.LiveReadiness.strategyGates)
                    Spacer()
                    Text(L10n.LiveReadiness.gateCount(passedCount, gates.count))
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(passedCount == gates.count ? PulseColors.accent : colors.textSecondary)
                }
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.sm)

                Divider().background(colors.border)

                // Gate rows
                ForEach(Array(gates.enumerated()), id: \.element.id) { index, gate in
                    gateRow(gate: gate, seq: index + 1)
                    if index < gates.count - 1 {
                        Divider().background(colors.border).padding(.leading, 4)
                    }
                }
            }
        }
    }

    private func gateRow(gate: StrategyGate, seq: Int) -> some View {
        HStack(spacing: 0) {
            // Status strip (4px, hazard stripes if failed)
            if gate.passed {
                Rectangle()
                    .fill(PulseColors.accent)
                    .frame(width: 4)
            } else {
                HazardStripe()
                    .frame(width: 4)
            }

            HStack(spacing: PulseSpacing.sm) {
                // Sequence number
                Text(String(format: "%02d", seq))
                    .font(.system(size: 18, weight: .regular, design: .monospaced))
                    .foregroundStyle(gate.passed ? PulseColors.accent : PulseColors.danger)
                    .frame(width: 28)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(gate.shortLabel)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)

                    if !gate.passed && !gate.remedy.isEmpty {
                        Text("→ \(gate.remedy)")
                            .font(PulseFonts.caption)
                            .foregroundStyle(PulseColors.danger.opacity(0.8))
                    }
                }

                Spacer()

                // GO / NO-GO verdict
                Text(gate.passed ? L10n.LiveReadiness.go : L10n.LiveReadiness.noGo)
                    .font(PulseFonts.micro)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(gate.passed ? PulseColors.accent : PulseColors.danger)
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(gate.passed ? PulseColors.accent.opacity(0.08) : PulseColors.danger.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke(gate.passed ? PulseColors.accent.opacity(0.15) : PulseColors.danger.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.sm)
        }
        .frame(minHeight: 52)
    }
}

// 45-degree hazard stripes
struct HazardStripe: View {
    var body: some View {
        GeometryReader { geo in
            let stripeWidth: CGFloat = 4
            Path { path in
                var y: CGFloat = -geo.size.height
                while y < geo.size.height * 2 {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y + geo.size.width))
                    y += stripeWidth * 2
                }
            }
            .stroke(PulseColors.danger, lineWidth: stripeWidth / 2)
            .clipped()
        }
    }
}
