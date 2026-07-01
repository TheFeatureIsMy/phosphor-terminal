// RiskWarningsPanel.swift — Risk warnings (always visible) + strategy-level clusters.
// Adapts RiskWarningRules.riskWarnings(for:) — returns [RiskWarning] with id + level only;
// this panel resolves display messages via @MainActor riskWarningMessage(id:) and
// annotates small-sample warnings when totalTrades < 30.

import SwiftUI

private struct DisplayWarning: Identifiable {
    let id: String
    let level: RiskWarningLevel
    let message: String
    var smallSample: Bool = false
}

struct RiskWarningsPanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.Context.risk).font(PulseFonts.caption.weight(.semibold))
            let warnings = computeWarnings()
            if warnings.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(PulseColors.success)
                    Text(L10n.BacktestLab.Context.noRisk).font(PulseFonts.micro).foregroundStyle(PulseColors.success)
                }
            } else {
                ForEach(warnings) { w in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: w.level == .red ? "xmark.shield.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(w.level == .red ? PulseColors.danger : PulseColors.amber)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.message).font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
                            if w.smallSample {
                                Text(L10n.BacktestLab.Context.smallSample)
                                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                            }
                        }
                    }
                }
            }
            // Strategy-level clusters
            if !vm.strategyFailureClusters.isEmpty {
                Divider().background(colors.border)
                Text(L10n.BacktestLab.Context.strategyClusters).font(PulseFonts.caption.weight(.semibold))
                ForEach(vm.strategyFailureClusters) { c in
                    HStack {
                        Text(c.label).font(PulseFonts.micro)
                        Spacer()
                        Text("\(c.sampleSize) \u{00B7} \(String(format: "%.2f", c.totalLoss))")
                            .font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
                    }
                }
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.surfaceHover.opacity(0.35), in: RoundedRectangle(cornerRadius: PulseRadii.md))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 1))
    }

    private func computeWarnings() -> [DisplayWarning] {
        guard let run = vm.currentBacktestRun else { return [] }
        let metrics = BacktestMetrics(
            totalReturn: run.totalReturn,
            sharpeRatio: run.sharpeRatio,
            maxDrawdown: run.maxDrawdown,
            winRate: run.winRate,
            profitFactor: run.profitFactor,
            totalTrades: run.totalTrades,
            avgTradeDuration: "",
            bestTrade: 0,
            worstTrade: 0
        )
        let raw = riskWarnings(for: metrics)
        return raw.map { w in
            let msg = riskWarningMessage(id: w.id)
            let small = w.id == "low_trades" && run.totalTrades < 30
            return DisplayWarning(id: w.id, level: w.level, message: msg, smallSample: small)
        }
    }
}
