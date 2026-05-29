// VariableSelector.swift — 上游变量选择器下拉菜单
// 计算当前节点的上游节点，列出可用输出端口作为变量引用

import SwiftUI

struct VariableSelector: View {
    let nodeId: UUID
    let edges: [CanvasEdge]
    let nodes: [CanvasNode]
    @Binding var selectedVar: VariableRef?

    var body: some View {
        Menu {
            if upstreamNodes.isEmpty {
                Text("无可用变量")
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.textMuted)
            } else {
                ForEach(upstreamNodes) { node in
                    let def = NodeRegistry.definition(for: node.nodeType)
                    Section(def?.name ?? node.nodeType) {
                        ForEach(def?.outputPorts ?? []) { port in
                            Button {
                                selectedVar = VariableRef(nodeId: node.id, variableName: port.name)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(port.dataType.color)
                                        .frame(width: 6, height: 6)
                                    Text(port.name)
                                        .font(PulseFonts.caption)
                                    Spacer()
                                    Text(port.dataType.label)
                                        .font(PulseFonts.micro)
                                        .foregroundStyle(PulseColors.textMuted)
                                }
                            }
                        }
                    }
                }

                if selectedVar != nil {
                    Divider()
                    Button {
                        selectedVar = nil
                    } label: {
                        Text("清除选择")
                            .font(PulseFonts.caption)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedVarDisplay)
                    .font(PulseFonts.caption)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(PulseColors.textMuted)
            }
            .foregroundStyle(selectedVar != nil ? PulseColors.textPrimary : PulseColors.textSecondary)
            .padding(PulseSpacing.xs)
            .background(PulseColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(PulseColors.border, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Computed

    private var upstreamNodes: [CanvasNode] {
        let upstreamIds = Set(
            edges.filter { $0.targetNodeId == nodeId }.map(\.sourceNodeId)
        )
        return nodes.filter { upstreamIds.contains($0.id) }
    }

    private var selectedVarDisplay: String {
        guard let selectedVar else { return "选择变量..." }
        let node = nodes.first { $0.id == selectedVar.nodeId }
        let def = node.flatMap { NodeRegistry.definition(for: $0.nodeType) }
        return "\(def?.name ?? "?") -> \(selectedVar.variableName)"
    }
}
