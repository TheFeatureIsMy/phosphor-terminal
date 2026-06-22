// RiskBindingPanel.swift — ⌘4 panel placeholder (Task 22 replaces body).
import SwiftUI

struct RiskBindingPanel: View {
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(title: L10n.Workbench.panelRisk, icon: WorkbenchPanel.risk.icon, onClose: { vm.closePanel() }) {
            Text("⌘4 — risk binding")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(.secondary)
        }
    }
}
