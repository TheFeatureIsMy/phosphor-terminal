// CanvasEdges.swift — 画布连线渲染
// 使用 SwiftUI Canvas 绘制贝塞尔曲线连线

import SwiftUI

struct CanvasEdges: View {
    let edges: [CanvasEdge]
    let nodes: [CanvasNode]
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
            for edge in edges {
                guard let sourceNode = nodeMap[edge.sourceNodeId],
                      let targetNode = nodeMap[edge.targetNodeId] else { continue }

                // Calculate port positions (right side of source, left side of target)
                let from = CGPoint(
                    x: sourceNode.position.x + sourceNode.size.width,
                    y: sourceNode.position.y + sourceNode.size.height / 2
                )
                let to = CGPoint(
                    x: targetNode.position.x,
                    y: targetNode.position.y + targetNode.size.height / 2
                )

                // Apply viewport transform
                let screenFrom = CGPoint(
                    x: from.x * scale + offset.x,
                    y: from.y * scale + offset.y
                )
                let screenTo = CGPoint(
                    x: to.x * scale + offset.x,
                    y: to.y * scale + offset.y
                )

                drawBezierWire(
                    context: context,
                    from: screenFrom,
                    to: screenTo,
                    color: edge.dataType.color
                )
            }
        }
    }

    private func drawBezierWire(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = abs(to.x - from.x) * 0.5
        var path = Path()
        path.move(to: from)
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x + dx, y: from.y),
            control2: CGPoint(x: to.x - dx, y: to.y)
        )
        context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 2)
    }
}
