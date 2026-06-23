import SwiftUI

struct TradeListPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionTradeList, locked: viewModel.phase != .completed) {
            if viewModel.phase != .completed {
                Text(L10n.BacktestLab.phaseWaitingComplete).foregroundStyle(.secondary)
            } else if let r = viewModel.selectedRun {
                if r.trades.isEmpty {
                    Text(L10n.BacktestLab.tradesEmpty).foregroundStyle(.secondary)
                } else {
                    tradesTable(r.trades)
                    runClusters(r.trades)
                }
            }
        }
    }

    @ViewBuilder
    private func tradesTable(_ trades: [TradeRow]) -> some View {
        Table(trades) {
            TableColumn(L10n.BacktestLab.colTime) { Text($0.openTime) }
            TableColumn(L10n.BacktestLab.colPair) { Text($0.pair) }
            TableColumn(L10n.BacktestLab.colSide) { Text($0.side) }
            TableColumn(L10n.BacktestLab.colEntry) { Text(String(format: "%.2f", $0.openPrice)) }
            TableColumn(L10n.BacktestLab.colExit) { Text(String(format: "%.2f", $0.closePrice)) }
            TableColumn(L10n.BacktestLab.colQty) { Text(String(format: "%.4f", $0.quantity)) }
            TableColumn(L10n.BacktestLab.colPnl) { row in
                Text(String(format: "%.2f", row.profit))
                    .foregroundStyle(row.profit >= 0 ? PulseColors.success : PulseColors.danger)
            }
            TableColumn(L10n.BacktestLab.colDuration) { Text($0.duration) }
            TableColumn(L10n.BacktestLab.colMtf) { Text($0.mtfState ?? "—") }
        }
        .frame(minHeight: 240)
    }

    @ViewBuilder
    private func runClusters(_ trades: [TradeRow]) -> some View {
        let clusters = clusterFailures(in: trades)
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.runClusterTitle).font(PulseFonts.headline)
            if clusters.isEmpty {
                Text(L10n.BacktestLab.runClusterTooFew).foregroundStyle(.secondary)
            } else {
                ForEach(clusters) { c in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(c.label).font(PulseFonts.body)
                            Text(c.commonFeatures.joined(separator: " · ")).font(PulseFonts.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("n=\(c.sampleSize)").font(PulseFonts.caption)
                            Text(String(format: "%.2f", c.totalLoss))
                                .foregroundStyle(PulseColors.danger).font(PulseFonts.caption)
                        }
                    }
                    .padding(PulseSpacing.xs)
                    .background(PulseColors.danger.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
            }
        }
    }
}
