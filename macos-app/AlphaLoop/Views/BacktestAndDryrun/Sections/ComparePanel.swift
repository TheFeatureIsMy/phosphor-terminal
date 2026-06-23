import SwiftUI
import Charts

struct ComparePanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        if !viewModel.comparedRunIds.isEmpty {
            SectionCard(title: L10n.BacktestLab.sectionCompare) {
                matrix
                if !viewModel.comparedRuns.isEmpty {
                    overlayChart
                }
            }
        } else {
            SectionCard(title: L10n.BacktestLab.sectionCompare) {
                Text(L10n.BacktestLab.compareEmpty).foregroundStyle(.secondary)
            }
        }
    }

    private var matrix: some View {
        let runs = viewModel.comparedRuns
        return Table(runs) {
            TableColumn("Run") { Text("#\($0.id)") }
            TableColumn(L10n.BacktestLab.metricReturn) { Text(String(format: "%.2f%%", $0.totalReturn * 100)) }
            TableColumn(L10n.BacktestLab.kpiSharpe) { Text(String(format: "%.2f", $0.sharpeRatio)) }
            TableColumn(L10n.BacktestLab.metricMaxDrawdown) { Text(String(format: "%.2f%%", $0.maxDrawdown * 100)) }
            TableColumn(L10n.BacktestLab.metricWinRate) { Text(String(format: "%.1f%%", $0.winRate * 100)) }
            TableColumn(L10n.BacktestLab.metricProfitFactor) { Text(String(format: "%.2f", $0.profitFactor)) }
            TableColumn(L10n.BacktestLab.kpiTrades) { Text("\($0.totalTrades)") }
        }
        .frame(minHeight: CGFloat(max(80, runs.count * 36)))
    }

    private var overlayChart: some View {
        let colors: [Color] = [PulseColors.accent, PulseColors.success, PulseColors.info]
        return Chart {
            ForEach(Array(viewModel.comparedRuns.enumerated()), id: \.element.id) { idx, run in
                ForEach(run.equityCurve) { pt in
                    LineMark(
                        x: .value("Time", pt.timestamp),
                        y: .value("Equity", pt.equity)
                    )
                    .foregroundStyle(colors[idx % colors.count])
                }
            }
        }
        .frame(height: 180)
    }
}
