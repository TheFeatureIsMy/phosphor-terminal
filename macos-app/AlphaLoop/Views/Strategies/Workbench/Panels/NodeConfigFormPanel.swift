// NodeConfigPanel.swift — ⌘2 panel placeholder (Task 20 replaces body).
import SwiftUI

struct NodeConfigPanel: View {
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(title: L10n.Workbench.panelNode, icon: WorkbenchPanel.node.icon, onClose: { vm.closePanel() }) {
            Text("⌘2 — node config")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(.secondary)
        }
    }
}
