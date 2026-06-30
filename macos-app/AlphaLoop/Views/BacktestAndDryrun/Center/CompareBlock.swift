// CompareBlock.swift — KPI matrix + equity overlay for compared runs.

import SwiftUI
import Charts

struct CompareBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionCompare, dataNote: "\(vm.comparedRuns.count) runs") {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                kpiMatrix
                overlayChart
            }
        }
    }

    private var kpiMatrix: some View {
        let rows = vm.comparedRuns
        return Grid {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                ForEach(rows) { r in
                    Text("#\(r.id)").font(PulseFonts.micro)
                }
            }
            GridRow {
                Text(L10n.BacktestLab.kpiReturn).font(PulseFonts.micro)
                ForEach(rows) { r in
                    Text(String(format: "%+.1f%%", r.totalReturn * 100)).font(PulseFonts.micro)
                }
            }
            GridRow {
                Text(L10n.BacktestLab.kpiMaxDD).font(PulseFonts.micro)
                ForEach(rows) { r in
                    Text(String(format: "%.1f%%", r.maxDrawdown * 100)).font(PulseFonts.micro)
                }
            }
            GridRow {
                Text(L10n.BacktestLab.kpiWinRate).font(PulseFonts.micro)
                ForEach(rows) { r in
                    Text(String(format: "%.0f%%", r.winRate * 100)).font(PulseFonts.micro)
                }
            }
            GridRow {
                Text(L10n.BacktestLab.kpiProfitFactor).font(PulseFonts.micro)
                ForEach(rows) { r in
                    Text(String(format: "%.2f", r.profitFactor)).font(PulseFonts.micro)
                }
            }
        }
    }

    private var overlayChart: some View {
        let chartColors: [Color] = [PulseColors.accent, PulseColors.cyan, PulseColors.purple]
        return Chart {
            ForEach(Array(vm.comparedRuns.enumerated()), id: \.element.id) { idx, run in
                ForEach(run.equityCurve) { p in
                    LineMark(
                        x: .value("Time", p.timestamp),
                        y: .value("Equity", p.equity)
                    )
                    .foregroundStyle(chartColors[idx % chartColors.count])
                }
            }
        }
        .frame(height: 160)
    }
}
