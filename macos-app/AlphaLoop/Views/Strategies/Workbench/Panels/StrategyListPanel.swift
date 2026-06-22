// StrategyListPanel.swift — ⌘1 panel placeholder (Task 19 replaces body).
import SwiftUI

struct StrategyListPanel: View {
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(title: L10n.Workbench.panelList, icon: WorkbenchPanel.list.icon, onClose: { vm.closePanel() }) {
            Text("⌘1 — strategy list")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(.secondary)
        }
    }
}
