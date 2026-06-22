// VersionsPanel.swift — ⌘3 panel placeholder (Task 21 replaces body).
import SwiftUI

struct VersionsPanel: View {
    let vm: StrategyWorkspaceViewModel

    var body: some View {
        PanelChrome(title: L10n.Workbench.panelVersion, icon: WorkbenchPanel.version.icon, onClose: { vm.closePanel() }) {
            Text("⌘3 — versions")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(.secondary)
        }
    }
}
