import SwiftUI

struct CanvasEdges: View {
    @Environment(PulseColors.self) private var colors
    let edges: [CanvasEdge]
    let nodes: [CanvasNode]
    let selectedEdgeIds: Set<UUID>
    let scale: CGFloat
    let offset: CGPoint

    private let router = EdgeRouter()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
                let now = timeline.date.timeIntervalSinceReferenceDate

                for edge in edges {
                    guard let sourceNode = nodeMap[edge.sourceNodeId],
                          let targetNode = nodeMap[edge.targetNodeId],
                          let sourceDef = NodeRegistry.definition(for: sourceNode.nodeType),
                          let targetDef = NodeRegistry.definition(for: targetNode.nodeType),
                          let from = router.portPosition(node: sourceNode, definition: sourceDef, portName: edge.sourcePort, isInput: false),
                          let to = router.portPosition(node: targetNode, definition: targetDef, portName: edge.targetPort, isInput: true)
                    else { continue }

                    // Viewport transform
                    let screenFrom = CGPoint(x: from.x * scale + offset.x, y: from.y * scale + offset.y)
                    let screenTo = CGPoint(x: to.x * scale + offset.x, y: to.y * scale + offset.y)

                    let isSelected = selectedEdgeIds.contains(edge.id)
                    let lineWidth: CGFloat = isSelected ? 3 : 2
                    let color = edge.dataType.color(colors)
                    let opacity: CGFloat = sourceNode.isDisabled ? 0.3 : 0.7

                    drawBezierWire(context: context, from: screenFrom, to: screenTo,
                                   color: color.opacity(opacity), lineWidth: lineWidth)

                    if isSelected {
                        drawBezierWire(context: context, from: screenFrom, to: screenTo,
                                       color: color.opacity(0.3), lineWidth: 6)
                    }

                    // Data-flow particles (only when zoomed in enough)
                    if scale > 0.3 {
                        drawParticles(context: context, from: screenFrom, to: screenTo,
                                      color: color, now: now, edgeId: edge.id)
                    }
                }
            }
        }
    }

    private func drawBezierWire(context: GraphicsContext, from: CGPoint, to: CGPoint,
                                 color: Color, lineWidth: CGFloat) {
        let dx = abs(to.x - from.x) * 0.5
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to,
                      control1: CGPoint(x: from.x + max(dx, 40), y: from.y),
                      control2: CGPoint(x: to.x - max(dx, 40), y: to.y))
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawParticles(context: GraphicsContext, from: CGPoint, to: CGPoint,
                                color: Color, now: TimeInterval, edgeId: UUID) {
        let distance = hypot(to.x - from.x, to.y - from.y)
        let spacing: CGFloat = 80
        let count = max(1, Int(distance / spacing))
        let speed: CGFloat = 0.3

        for i in 0..<count {
            let baseT = CGFloat(i) / CGFloat(count)
            let particleT = (baseT + CGFloat(now) * speed).truncatingRemainder(dividingBy: 1.0)
            let dx = abs(to.x - from.x) * 0.5
            let cp1 = CGPoint(x: from.x + max(dx, 40), y: from.y)
            let cp2 = CGPoint(x: to.x - max(dx, 40), y: to.y)

            let p1 = cubicBezierPoint(t: particleT, p0: from, p1: cp1, p2: cp2, p3: to)
            let dotSize: CGFloat = 3
            let dotRect = CGRect(x: p1.x - dotSize/2, y: p1.y - dotSize/2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.6)))
        }
    }

    private func cubicBezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}
