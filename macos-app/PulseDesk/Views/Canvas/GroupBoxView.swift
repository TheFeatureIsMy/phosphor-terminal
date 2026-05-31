// GroupBoxView.swift — 节点分组框叠加层
// 虚线边框包裹组内节点，顶部显示组标题

import SwiftUI

struct GroupBoxView: View {
    @Environment(PulseColors.self) private var colors
    let group: NodeGroup
    let nodes: [CanvasNode]

    var body: some View {
        if !group.nodeIds.isEmpty {
            let bounds = computeBounds()

            ZStack(alignment: .top) {
            // Dashed border background
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(PulseColors.accent.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.md)
                        .stroke(
                            PulseColors.accent.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                )

            // Title badge
            Text(group.title)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(PulseColors.accent)
                .padding(.horizontal, PulseSpacing.xs)
                .padding(.vertical, 2)
                .background(colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadii.xs))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(PulseColors.accent.opacity(0.2), lineWidth: 1)
                )
                .offset(y: -PulseSpacing.xs)
        }
        .frame(width: bounds.width + PulseSpacing.xl, height: bounds.height + PulseSpacing.xxl + PulseSpacing.xxs)
        .position(x: bounds.midX, y: bounds.midY - 5)
        .animation(.easeInOut(duration: 0.2), value: bounds)
        }
    }

    private func computeBounds() -> CGRect {
        let groupNodes = nodes.filter { group.nodeIds.contains($0.id) }
        guard let first = groupNodes.first else { return .zero }
        var rect = CGRect(origin: first.position, size: first.size)
        for node in groupNodes.dropFirst() {
            rect = rect.union(CGRect(origin: node.position, size: node.size))
        }
        return rect
    }
}
