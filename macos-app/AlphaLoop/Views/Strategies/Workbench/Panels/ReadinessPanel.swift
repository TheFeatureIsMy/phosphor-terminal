// ReadinessPanel.swift — ⌘6 panel placeholder (Task 24 replaces body).
import SwiftUI

struct ReadinessPanel: View {
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(title: L10n.Workbench.panelReadiness, icon: WorkbenchPanel.readiness.icon, onClose: { vm.closePanel() }) {
            Text("⌘6 — readiness")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(.secondary)
        }
    }
}
