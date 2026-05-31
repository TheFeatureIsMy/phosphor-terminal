// CanvasEdges.swift — 连线渲染
// Bezier 曲线，橡皮筋预览线，箭头

import SwiftUI

struct CanvasEdges: View {
    @Environment(PulseColors.self) private var colors
    let edges: [CanvasEdge]
    let nodes: [CanvasNode]
    let selectedEdgeIds: Set<UUID>
    let scale: CGFloat
    let offset: CGPoint

    // Rubber-band preview line (from source port position to cursor)
    var rubberBand: (from: CGPoint, to: CGPoint)?

    var body: some View {
        Canvas { context, size in
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

            for edge in edges {
                guard let srcNode = nodeMap[edge.sourceNodeId],
                      let tgtNode = nodeMap[edge.targetNodeId],
                      let srcDef = NodeRegistry.definition(for: srcNode.nodeType),
                      let tgtDef = NodeRegistry.definition(for: tgtNode.nodeType) else { continue }

                let from = portScreenPos(node: srcNode, portKey: edge.sourcePortKey, definition: srcDef)
                let to = portScreenPos(node: tgtNode, portKey: edge.targetPortKey, definition: tgtDef)

                let isSelected = selectedEdgeIds.contains(edge.id)
                let dataType = srcDef.outputPorts.first { $0.key == edge.sourcePortKey }?.dataType ?? .signal
                let color = dataType.color(colors)
                let lineWidth: CGFloat = isSelected ? 3.0 : 1.5
                let opacity: CGFloat = srcNode.isDisabled || tgtNode.isDisabled ? 0.3 : 0.8

                drawBezier(context: context, from: from, to: to, color: color.opacity(opacity), lineWidth: lineWidth)
                drawArrowhead(context: context, at: to, from: from, color: color.opacity(opacity))
            }

            // Rubber-band preview line
            if let rb = rubberBand {
                var path = Path()
                path.move(to: rb.from)
                let dx = abs(rb.to.x - rb.from.x) * 0.4
                path.addCurve(to: rb.to,
                              control1: CGPoint(x: rb.from.x + dx, y: rb.from.y),
                              control2: CGPoint(x: rb.to.x - dx, y: rb.to.y))
                context.stroke(path, with: .color(PulseColors.accent.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
    }

    // Bezier curve
    private func drawBezier(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: from)

        let dx = abs(to.x - from.x) * 0.4
        let cp1 = CGPoint(x: from.x + dx, y: from.y)
        let cp2 = CGPoint(x: to.x - dx, y: to.y)

        path.addCurve(to: to, control1: cp1, control2: cp2)
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    // Arrowhead at target end
    private func drawArrowhead(context: GraphicsContext, at point: CGPoint, from: CGPoint, color: Color) {
        let angle = atan2(point.y - from.y, point.x - from.x)
        let sz: CGFloat = 6
        var arrow = Path()
        arrow.move(to: point)
        arrow.addLine(to: CGPoint(x: point.x - sz * cos(angle - .pi / 6),
                                   y: point.y - sz * sin(angle - .pi / 6)))
        arrow.addLine(to: CGPoint(x: point.x - sz * cos(angle + .pi / 6),
                                   y: point.y - sz * sin(angle + .pi / 6)))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }

    // Port screen position using PortDirection
    private func portScreenPos(node: CanvasNode, portKey: String, definition: NodeDefinition) -> CGPoint {
        let titleH: CGFloat = 32
        let y = portY(node: node, portKey: portKey, definition: definition, titleH: titleH)

        let allInputs = definition.inputPorts
        let isInput = allInputs.contains { $0.key == portKey }
        let x = isInput ? node.position.x : node.position.x + node.size.width

        return CGPoint(x: x * scale + offset.x, y: y * scale + offset.y)
    }

    private func portY(node: CanvasNode, portKey: String, definition: NodeDefinition, titleH: CGFloat) -> CGFloat {
        let inputPorts = definition.inputPorts
        let outputPorts = definition.outputPorts

        if let idx = inputPorts.firstIndex(where: { $0.key == portKey }) {
            let bodyH = node.isCollapsed ? 0 : node.size.height - titleH
            let count = inputPorts.count
            let spacing = bodyH / CGFloat(max(count, 1) + 1)
            return node.position.y + titleH + spacing * CGFloat(idx + 1)
        }
        if let idx = outputPorts.firstIndex(where: { $0.key == portKey }) {
            let bodyH = node.isCollapsed ? 0 : node.size.height - titleH
            let count = outputPorts.count
            let spacing = bodyH / CGFloat(max(count, 1) + 1)
            return node.position.y + titleH + spacing * CGFloat(idx + 1)
        }
        return node.position.y + node.size.height / 2
    }
}
