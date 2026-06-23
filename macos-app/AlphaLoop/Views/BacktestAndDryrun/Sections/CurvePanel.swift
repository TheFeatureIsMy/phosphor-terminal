import SwiftUI
import Charts

struct CurvePanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionCurve, locked: viewModel.phase != .completed) {
            if viewModel.phase != .completed {
                Text(L10n.BacktestLab.phaseWaitingComplete).foregroundStyle(.secondary)
            } else if let r = viewModel.selectedRun {
                if r.equityCurve.isEmpty {
                    Text(L10n.BacktestLab.curveEmpty).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: PulseSpacing.md) {
                        Chart {
                            ForEach(r.equityCurve) { pt in
                                LineMark(x: .value("Time", pt.timestamp), y: .value("Equity", pt.equity))
                                    .foregroundStyle(PulseColors.accent)
                                AreaMark(x: .value("Time", pt.timestamp), y: .value("Equity", pt.equity))
                                    .foregroundStyle(.linearGradient(colors: [PulseColors.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 180)

                        Chart {
                            ForEach(r.equityCurve) { pt in
                                BarMark(x: .value("Time", pt.timestamp), y: .value("Drawdown", pt.drawdown))
                                    .foregroundStyle(PulseColors.danger)
                            }
                        }
                        .frame(height: 80)
                    }
                }
            }
        }
    }
}
