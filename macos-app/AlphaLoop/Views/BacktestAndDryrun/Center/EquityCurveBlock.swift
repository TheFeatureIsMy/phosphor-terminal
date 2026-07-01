// EquityCurveBlock.swift — Equity curve + drawdown chart.

import SwiftUI
import Charts

struct EquityCurveBlock: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(PulseColors.self) private var colors

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionCurve, dataNote: dataNote) {
            if let run = vm.currentBacktestRun, !run.equityCurve.isEmpty {
                VStack(spacing: PulseSpacing.sm) {
                    Chart(run.equityCurve) { p in
                        LineMark(
                            x: .value("Time", p.timestamp),
                            y: .value("Equity", p.equity)
                        )
                        .foregroundStyle(PulseColors.accent)
                        AreaMark(
                            x: .value("Time", p.timestamp),
                            y: .value("Equity", p.equity)
                        )
                        .foregroundStyle(PulseColors.accent.opacity(0.2))
                    }
                    .frame(height: 180)

                    Chart(run.equityCurve) { p in
                        BarMark(
                            x: .value("Time", p.timestamp),
                            y: .value("DD", p.drawdown)
                        )
                        .foregroundStyle(PulseColors.danger.opacity(0.5))
                    }
                    .frame(height: 80)
                }
            } else {
                Text(L10n.BacktestLab.curveEmpty)
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }

    private var dataNote: String {
        guard let run = vm.currentBacktestRun, !run.equityCurve.isEmpty else { return "" }
        return "\(run.equityCurve.count) points"
    }
}
