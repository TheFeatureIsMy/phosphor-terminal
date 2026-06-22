// BacktestDryrunPanel.swift — ⌘5 panel placeholder (Task 23 replaces body).
import SwiftUI

struct BacktestDryrunPanel: View {
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(title: L10n.Workbench.panelBacktest, icon: WorkbenchPanel.backtest.icon, onClose: { vm.closePanel() }) {
            Text("⌘5 — backtest / dryrun")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(.secondary)
        }
    }
}
