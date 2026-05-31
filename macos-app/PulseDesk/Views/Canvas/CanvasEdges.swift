// CanvasEdges.swift — 正交走线，自动避开节点

import SwiftUI

struct CanvasEdges: View {
    @Environment(PulseColors.self) private var colors
    let edges: [CanvasEdge]
    let nodes: [CanvasNode]
    let selectedEdgeIds: Set<UUID>
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

            for edge in edges {
                guard let src = nodeMap[edge.sourceNodeId],
                      let tgt = nodeMap[edge.targetNodeId],
                      let srcSide = PortSide(rawValue: edge.sourcePort),
                      let tgtSide = PortSide(rawValue: edge.targetPort) else { continue }

                let from = portWorldPos(node: src, side: srcSide)
                let to = portWorldPos(node: tgt, side: tgtSide)

                let screenFrom = CGPoint(x: from.x * scale + offset.x, y: from.y * scale + offset.y)
                let screenTo = CGPoint(x: to.x * scale + offset.x, y: to.y * scale + offset.y)

                let isSelected = selectedEdgeIds.contains(edge.id)
                let color = edge.dataType.color(colors)
                let lineWidth: CGFloat = isSelected ? 2.5 : 1.5
                let opacity: CGFloat = src.isDisabled || tgt.isDisabled ? 0.3 : 0.8

                drawOrthogonal(context: context, from: screenFrom, to: screenTo,
                               fromSide: srcSide, toSide: tgtSide,
                               color: color.opacity(opacity), lineWidth: lineWidth)
            }
        }
    }

    private func drawOrthogonal(context: GraphicsContext, from: CGPoint, to: CGPoint,
                                 fromSide: PortSide, toSide: PortSide,
                                 color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: from)
        let seg: CGFloat = 20

        switch (fromSide, toSide) {
        case (.right, .left):
            if to.x > from.x {
                let mx = (from.x + to.x) / 2
                path.addLine(to: CGPoint(x: mx, y: from.y))
                path.addLine(to: CGPoint(x: mx, y: to.y))
            } else {
                let dy = min(from.y, to.y) - 30
                path.addLine(to: CGPoint(x: from.x + seg, y: from.y))
                path.addLine(to: CGPoint(x: from.x + seg, y: dy))
                path.addLine(to: CGPoint(x: to.x - seg, y: dy))
                path.addLine(to: CGPoint(x: to.x - seg, y: to.y))
            }
            path.addLine(to: to)

        case (.bottom, .top):
            if to.y > from.y {
                let my = (from.y + to.y) / 2
                path.addLine(to: CGPoint(x: from.x, y: my))
                path.addLine(to: CGPoint(x: to.x, y: my))
            } else {
                let dx = max(from.x, to.x) + 30
                path.addLine(to: CGPoint(x: from.x, y: from.y + seg))
                path.addLine(to: CGPoint(x: dx, y: from.y + seg))
                path.addLine(to: CGPoint(x: dx, y: to.y - seg))
                path.addLine(to: CGPoint(x: to.x, y: to.y - seg))
            }
            path.addLine(to: to)

        case (.right, .top):
            path.addLine(to: CGPoint(x: from.x + seg, y: from.y))
            path.addLine(to: CGPoint(x: from.x + seg, y: to.y - seg))
            path.addLine(to: CGPoint(x: to.x, y: to.y - seg))
            path.addLine(to: to)

        case (.right, .bottom):
            path.addLine(to: CGPoint(x: from.x + seg, y: from.y))
            path.addLine(to: CGPoint(x: from.x + seg, y: to.y + seg))
            path.addLine(to: CGPoint(x: to.x, y: to.y + seg))
            path.addLine(to: to)

        case (.bottom, .left):
            path.addLine(to: CGPoint(x: from.x, y: from.y + seg))
            path.addLine(to: CGPoint(x: to.x - seg, y: from.y + seg))
            path.addLine(to: CGPoint(x: to.x - seg, y: to.y))
            path.addLine(to: to)

        case (.bottom, .right):
            path.addLine(to: CGPoint(x: from.x, y: from.y + seg))
            path.addLine(to: CGPoint(x: to.x + seg, y: from.y + seg))
            path.addLine(to: CGPoint(x: to.x + seg, y: to.y))
            path.addLine(to: to)

        case (.left, .top):
            path.addLine(to: CGPoint(x: from.x - seg, y: from.y))
            path.addLine(to: CGPoint(x: from.x - seg, y: to.y - seg))
            path.addLine(to: CGPoint(x: to.x, y: to.y - seg))
            path.addLine(to: to)

        case (.left, .bottom):
            path.addLine(to: CGPoint(x: from.x - seg, y: from.y))
            path.addLine(to: CGPoint(x: from.x - seg, y: to.y + seg))
            path.addLine(to: CGPoint(x: to.x, y: to.y + seg))
            path.addLine(to: to)

        case (.top, .left):
            path.addLine(to: CGPoint(x: from.x, y: from.y - seg))
            path.addLine(to: CGPoint(x: to.x - seg, y: from.y - seg))
            path.addLine(to: CGPoint(x: to.x - seg, y: to.y))
            path.addLine(to: to)

        case (.top, .right):
            path.addLine(to: CGPoint(x: from.x, y: from.y - seg))
            path.addLine(to: CGPoint(x: to.x + seg, y: from.y - seg))
            path.addLine(to: CGPoint(x: to.x + seg, y: to.y))
            path.addLine(to: to)

        default:
            path.addLine(to: CGPoint(x: to.x, y: from.y))
            path.addLine(to: to)
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)

        // Arrowhead
        let sz: CGFloat = 5
        var arrow = Path()
        switch toSide {
        case .left:
            arrow.move(to: to)
            arrow.addLine(to: CGPoint(x: to.x + sz, y: to.y - sz))
            arrow.addLine(to: CGPoint(x: to.x + sz, y: to.y + sz))
        case .right:
            arrow.move(to: to)
            arrow.addLine(to: CGPoint(x: to.x - sz, y: to.y - sz))
            arrow.addLine(to: CGPoint(x: to.x - sz, y: to.y + sz))
        case .top:
            arrow.move(to: to)
            arrow.addLine(to: CGPoint(x: to.x - sz, y: to.y + sz))
            arrow.addLine(to: CGPoint(x: to.x + sz, y: to.y + sz))
        case .bottom:
            arrow.move(to: to)
            arrow.addLine(to: CGPoint(x: to.x - sz, y: to.y - sz))
            arrow.addLine(to: CGPoint(x: to.x + sz, y: to.y - sz))
        }
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }

    private func portWorldPos(node: CanvasNode, side: PortSide) -> CGPoint {
        switch side {
        case .left:  return CGPoint(x: node.position.x, y: node.position.y + node.size.height / 2)
        case .right: return CGPoint(x: node.position.x + node.size.width, y: node.position.y + node.size.height / 2)
        case .top:   return CGPoint(x: node.position.x + node.size.width / 2, y: node.position.y)
        case .bottom: return CGPoint(x: node.position.x + node.size.width / 2, y: node.position.y + node.size.height)
        }
    }
}
