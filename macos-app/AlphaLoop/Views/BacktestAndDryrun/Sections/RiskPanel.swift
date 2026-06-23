import SwiftUI

struct RiskPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionRisk) {
            if viewModel.phase == .failed {
                Text(L10n.BacktestLab.runFailedNoResult).foregroundStyle(PulseColors.danger)
            } else if let r = viewModel.selectedRun {
                let m = BacktestMetrics(
                    totalReturn: r.totalReturn,
                    sharpeRatio: r.sharpeRatio,
                    maxDrawdown: r.maxDrawdown,
                    winRate: r.winRate,
                    profitFactor: r.profitFactor,
                    totalTrades: r.totalTrades,
                    avgTradeDuration: "",
                    bestTrade: 0,
                    worstTrade: 0
                )
                let ws = riskWarnings(for: m)
                if !ws.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        ForEach(ws) { w in
                            HStack {
                                Circle().fill(w.level == .red ? PulseColors.danger : PulseColors.warning)
                                    .frame(width: 8, height: 8)
                                Text(riskWarningMessage(id: w.id)).font(PulseFonts.body)
                                Spacer()
                            }
                            .padding(PulseSpacing.xs)
                            .background((w.level == .red ? PulseColors.danger : PulseColors.warning).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                        }
                    }
                }
                strategyClusters
            }
        }
    }

    @ViewBuilder
    private var strategyClusters: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.strategyClusterTitle).font(PulseFonts.headline)
            if viewModel.strategyFailureClusters.isEmpty {
                Text(L10n.BacktestLab.strategyClusterEmpty).foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.strategyFailureClusters) { c in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c.label).font(PulseFonts.body)
                            Text(c.commonFeatures.joined(separator: " · ")).font(PulseFonts.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("n=\(c.sampleSize)").font(PulseFonts.caption)
                            Text(String(format: "%.2f", c.totalLoss)).foregroundStyle(PulseColors.danger).font(PulseFonts.caption)
                        }
                        Button(L10n.BacktestLab.generateShadow) { /* navigate to shadow strategy flow */ }
                            .font(PulseFonts.caption)
                    }
                    .padding(PulseSpacing.xs)
                    .background(PulseColors.danger.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
            }
        }
    }
}
