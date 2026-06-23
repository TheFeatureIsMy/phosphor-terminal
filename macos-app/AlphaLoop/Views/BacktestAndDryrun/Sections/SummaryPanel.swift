import SwiftUI

struct SummaryPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionSummary,
                    locked: viewModel.phase != .completed) {
            if viewModel.phase != .completed {
                Text(L10n.BacktestLab.phaseWaitingComplete).foregroundStyle(.secondary)
            } else if let r = viewModel.selectedRun {
                HStack(spacing: PulseSpacing.lg) {
                    metricCard(L10n.BacktestLab.metricReturn,
                               value: r.totalReturn, context: vsLastContext(r))
                    metricCard(L10n.BacktestLab.metricMaxDrawdown,
                               value: r.maxDrawdown, context: nil, alwaysNegative: true)
                    metricCard(L10n.BacktestLab.metricWinRate,
                               value: r.winRate, context: "\(r.totalTrades) trades", asPercent: true)
                    metricCard(L10n.BacktestLab.metricProfitFactor,
                               value: r.profitFactor, context: nil)
                }
            }
        }
    }

    private func vsLastContext(_ r: BacktestRunV2) -> String? {
        guard let prev = viewModel.recentBacktests.first(where: { $0.id != r.id }) else { return nil }
        let diff = r.totalReturn - prev.totalReturn
        let sign = diff >= 0 ? "+" : ""
        return "\(L10n.BacktestLab.metricVsLast) \(sign)\(String(format: "%.2f%%", diff * 100))"
    }

    private func metricCard(_ title: String, value: Double, context: String?,
                            alwaysNegative: Bool = false, asPercent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(title).font(PulseFonts.caption).foregroundStyle(.secondary)
            Text(asPercent ? String(format: "%.1f%%", value * 100) : String(format: "%.3f", value))
                .font(PulseFonts.tabularLarge)
                .foregroundStyle(alwaysNegative ? .red : (value >= 0 ? PulseColors.success : PulseColors.danger))
            if let context {
                Text(context).font(PulseFonts.micro).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
