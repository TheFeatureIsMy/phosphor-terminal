// NodeConfigPanel.swift — ⌘2 panel routing canvas selection → 9 native forms
// (Plan 2026-06-18 Task 20). Reads CanvasWebViewModel.selectedNode and routes
// by node type. Commits write back via canvasVM.updateNodeData(nodeId:data:).
import SwiftUI

struct NodeConfigPanel: View {
    @Environment(PulseColors.self) private var colors
    let vm: StrategyWorkspaceViewModel
    let canvasVM: CanvasWebViewModel?

    var body: some View {
        PanelChrome(
            title: L10n.Workbench.panelNode,
            icon: WorkbenchPanel.node.icon,
            onClose: { vm.closePanel() }
        ) {
            if let node = canvasVM?.selectedNode {
                VStack(alignment: .leading, spacing: 12) {
                    typeBadge(node.type)
                    Divider().overlay(colors.border)
                    form(for: node)
                }
            } else {
                Text(L10n.Workbench.nodeNoSelection)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }

    private func typeBadge(_ type: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(PulseColors.accent).frame(width: 6, height: 6)
            Text(displayName(for: type))
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Text(type)
                .font(PulseFonts.micro)
                .tracking(0.6)
                .foregroundStyle(colors.textMuted)
        }
    }

    private func displayName(for type: String) -> String {
        switch type {
        case "signalInput":        return L10n.Workbench.nodeSignalInput
        case "indicatorCondition": return L10n.Workbench.nodeIndicatorCondition
        case "filter":             return L10n.Workbench.nodeFilter
        case "positionSizing":     return L10n.Workbench.nodePositionSizing
        case "riskPolicy":         return L10n.Workbench.nodeRiskPolicy
        case "executionOutput":    return L10n.Workbench.nodeExecutionOutput
        case "structureDefense":   return L10n.Workbench.nodeStructureDefense
        case "accountRisk":        return L10n.Workbench.nodeAccountRisk
        case "mtfGuard":           return L10n.Workbench.nodeMTFGuard
        default:                   return type
        }
    }

    @ViewBuilder
    private func form(for node: CanvasNodeSelection) -> some View {
        let commit: ([String: Any]) -> Void = { newData in
            canvasVM?.updateNodeData(nodeId: node.id, data: newData)
        }
        switch node.type {
        case "signalInput":        SignalInputForm(initial: node.data, onCommit: commit)
        case "indicatorCondition": IndicatorConditionForm(initial: node.data, onCommit: commit)
        case "filter":             FilterForm(initial: node.data, onCommit: commit)
        case "positionSizing":     PositionSizingForm(initial: node.data, onCommit: commit)
        case "riskPolicy":         RiskPolicyForm(initial: node.data, onCommit: commit)
        case "executionOutput":    ExecutionOutputForm(initial: node.data, onCommit: commit)
        case "structureDefense":   StructureDefenseForm(initial: node.data, onCommit: commit)
        case "accountRisk":        AccountRiskForm(initial: node.data, onCommit: commit)
        case "mtfGuard":           MTFGuardForm(initial: node.data, onCommit: commit)
        default:
            Text(L10n.zh("未知节点类型", en: "Unknown node type"))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
    }
}
