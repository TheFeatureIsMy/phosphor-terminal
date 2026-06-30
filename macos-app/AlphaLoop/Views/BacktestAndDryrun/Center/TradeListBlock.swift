// TradeListBlock.swift — Trade table + run-level failure clustering.

import SwiftUI

struct TradeListBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionTradeList, dataNote: dataNote) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                if let run = vm.currentBacktestRun, !run.trades.isEmpty {
                    tradeTable(run.trades)
                    runLevelClusters(run.trades)
                } else {
                    Text(L10n.BacktestLab.tradesEmpty)
                        .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private var dataNote: String {
        guard let run = vm.currentBacktestRun else { return "" }
        return "\(run.totalTrades) trades"
    }

    private func tradeTable(_ trades: [TradeRow]) -> some View {
        Table(trades) {
            TableColumn(L10n.BacktestLab.colEntry) { Text($0.openTime).font(PulseFonts.micro) }
            TableColumn(L10n.BacktestLab.colPair) { Text($0.pair).font(PulseFonts.micro) }
            TableColumn(L10n.BacktestLab.colSide) { Text($0.side).font(PulseFonts.micro) }
            TableColumn(L10n.BacktestLab.colEntry) { Text(String(format: "%.2f", $0.openPrice)).font(PulseFonts.micro) }
            TableColumn(L10n.BacktestLab.colExit) { Text(String(format: "%.2f", $0.closePrice)).font(PulseFonts.micro) }
            TableColumn(L10n.BacktestLab.colPnl) { t in
                Text(String(format: "%+.2f", t.profit))
                    .font(PulseFonts.micro)
                    .foregroundStyle(t.profit >= 0 ? PulseColors.success : PulseColors.danger)
            }
            TableColumn(L10n.BacktestLab.colDuration) { Text($0.duration).font(PulseFonts.micro) }
        }
        .frame(minHeight: 200)
    }

    @ViewBuilder
    private func runLevelClusters(_ trades: [TradeRow]) -> some View {
        let clusters = clusterFailures(in: trades)
        if !clusters.isEmpty {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(L10n.BacktestLab.runClusterTitle).font(PulseFonts.caption.weight(.semibold))
                ForEach(clusters) { c in
                    HStack {
                        Text(c.label).font(PulseFonts.micro)
                        Spacer()
                        Text("\(c.sampleSize) x \(String(format: "%.2f", abs(c.totalLoss)))")
                            .font(PulseFonts.micro).foregroundStyle(PulseColors.danger)
                    }
                }
            }
        }
    }
}
