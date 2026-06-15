// StrategyRuntimeCard.swift — Strategy runtime metric card
// Large running count + detail dots for positions/pending/reconciling

import SwiftUI

struct StrategyRuntimeCard: View {
    @Environment(PulseColors.self) private var colors
    let runtime: RuntimeOverviewResponse

    @State private var displayCount: Double = 0
    @State private var hasAnimated = false

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: L10n.Dashboard.strategyRuntime)

                // Large number + unit
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", displayCount))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(PulseColors.purple)
                        .contentTransition(.numericText())

                    Text(L10n.Dashboard.running)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                .onAppear {
                    guard !hasAnimated else { return }
                    hasAnimated = true
                    withAnimation(.spring(response: 1.5, dampingFraction: 0.7)) {
                        displayCount = Double(runtime.runningStrategies)
                    }
                }
                .onChange(of: runtime.runningStrategies) { _, newValue in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        displayCount = Double(newValue)
                    }
                }

                // Detail dots row
                HStack(spacing: PulseSpacing.sm) {
                    detailDot(
                        color: PulseColors.cyan,
                        count: runtime.openPositions,
                        label: L10n.Dashboard.positions
                    )

                    detailDot(
                        color: PulseColors.warning,
                        count: runtime.pendingOrders,
                        label: L10n.Dashboard.pending
                    )

                    detailDot(
                        color: PulseColors.amber,
                        count: runtime.reconcilingCount,
                        label: L10n.Dashboard.reconciling
                    )
                }
            }
        }
    }

    // MARK: - Detail Dot

    private func detailDot(color: Color, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.4), radius: 2)

            Text("\(count) \(label)")
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textSecondary)
        }
    }
}
