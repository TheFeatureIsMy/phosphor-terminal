import SwiftUI

struct ConfigPanel: View {
    @Bindable var viewModel: BacktestLabViewModel

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionConfig, locked: viewModel.phase == .running) {
            if viewModel.selectedStrategy != nil {
                LabeledContent(L10n.BacktestLab.fieldTimeframe, value: "—")
                LabeledContent(
                    L10n.BacktestLab.fieldSymbols,
                    value: viewModel.selectedRun.map { $0.symbols.joined(separator: ", ") } ?? "—"
                )
                LabeledContent(
                    L10n.BacktestLab.fieldCapital,
                    value: String(format: "%.0f", viewModel.selectedRun?.initialCapital ?? 0)
                )
            } else {
                Text(L10n.BacktestLab.phaseIdle).foregroundStyle(.secondary)
            }
        }
    }
}
