// MiniMapView.swift — 画布右下角缩略图 (200x150)
// 显示所有节点为小色块 + 当前视口矩形，点击/拖拽可平移主画布

import SwiftUI

struct MiniMapView: View {
    @Environment(PulseColors.self) private var colors
    let nodes: [CanvasNode]
    var edges: [CanvasEdge] = []
    let viewport: ViewportState
    let canvasSize: CGSize
    var onPan: ((CGPoint) -> Void)?

    @State private var minimapSize: CGSize = CGSize(width: 200, height: 150)
    @State private var visibleOpacity: CGFloat = 0.4
    @State private var opacityTask: Task<Void, Never>?
    @State private var miniMapOffset: CGSize = .zero
    var selectedNodeIds: Set<UUID> = []

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Drag handle bar at top
            Capsule()
                .fill(colors.textMuted.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .top)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in
                            miniMapOffset = CGSize(
                                width: miniMapOffset.width + v.translation.width,
                                height: miniMapOffset.height + v.translation.height
                            )
                        }
                )

        Canvas { context, size in
            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: minimapSize)),
                with: .color(colors.surface.opacity(0.85))
            )

            // Grid lines for visual depth
            let gridSpacing: CGFloat = 20
            for x in stride(from: 0, through: minimapSize.width, by: gridSpacing) {
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.addLine(to: CGPoint(x: x, y: minimapSize.height))
                context.stroke(gridPath, with: .color(colors.border.opacity(0.3)), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: minimapSize.height, by: gridSpacing) {
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: minimapSize.width, y: y))
                context.stroke(gridPath, with: .color(colors.border.opacity(0.3)), lineWidth: 0.5)
            }

            guard !nodes.isEmpty else { return }
            let bounds = computeBounds()
            let scaleX = minimapSize.width / max(bounds.width, 1)
            let scaleY = minimapSize.height / max(bounds.height, 1)
            let scale = min(scaleX, scaleY, 1.0)

            // Draw nodes as small colored rectangles
            for node in nodes {
                let def = NodeRegistry.definition(for: node.nodeType)
                let isSelected = selectedNodeIds.contains(node.id)
                let color = isSelected ? PulseColors.accent : (def?.category.color ?? colors.textMuted)
                let nodeOpacity: Double = isSelected ? 0.9 : 0.7
                let x = (node.position.x - bounds.minX) * scale
                let y = (node.position.y - bounds.minY) * scale
                let w = max(node.size.width * scale, 4)
                let h = max(node.size.height * scale, 3)
                let rect = CGRect(x: x, y: y, width: w, height: h)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1),
                    with: .color(color.opacity(nodeOpacity))
                )
            }

            // Draw simplified edge lines
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
            for edge in edges {
                guard let srcNode = nodeMap[edge.sourceNodeId],
                      let tgtNode = nodeMap[edge.targetNodeId] else { continue }
                let sx = (srcNode.position.x + srcNode.size.width / 2 - bounds.minX) * scale
                let sy = (srcNode.position.y + srcNode.size.height / 2 - bounds.minY) * scale
                let tx = (tgtNode.position.x + tgtNode.size.width / 2 - bounds.minX) * scale
                let ty = (tgtNode.position.y + tgtNode.size.height / 2 - bounds.minY) * scale
                var edgePath = Path()
                edgePath.move(to: CGPoint(x: sx, y: sy))
                edgePath.addLine(to: CGPoint(x: tx, y: ty))
                context.stroke(edgePath, with: .color(colors.border.opacity(0.4)), lineWidth: 0.5)
            }

            // Draw viewport rectangle
            let vpX = (-viewport.offset.x / viewport.scale - bounds.minX) * scale
            let vpY = (-viewport.offset.y / viewport.scale - bounds.minY) * scale
            let vpW = (canvasSize.width / viewport.scale) * scale
            let vpH = (canvasSize.height / viewport.scale) * scale
            let vpRect = CGRect(x: vpX, y: vpY, width: vpW, height: vpH)

            // Fill viewport area
            context.fill(
                Path(vpRect),
                with: .color(PulseColors.accent.opacity(0.08))
            )
            // Stroke viewport border
            context.stroke(
                Path(vpRect),
                with: .color(PulseColors.accent.opacity(0.6)),
                lineWidth: 1.5
            )
        }
        .frame(width: minimapSize.width, height: minimapSize.height)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .opacity(visibleOpacity)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !nodes.isEmpty else { return }
                    let bounds = computeBounds()
                    let scaleX = minimapSize.width / max(bounds.width, 1)
                    let scaleY = minimapSize.height / max(bounds.height, 1)
                    let scale = min(scaleX, scaleY, 1.0)

                    // Convert minimap click to world coordinates
                    let worldX = value.location.x / scale + bounds.minX
                    let worldY = value.location.y / scale + bounds.minY
                    onPan?(CGPoint(x: -worldX * viewport.scale, y: -worldY * viewport.scale))
                }
        )

            // Resize handle
            Circle()
                .fill(colors.textMuted.opacity(0.4))
                .frame(width: 10, height: 10)
                .padding(2)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in
                            let newW = max(100, min(400, minimapSize.width + v.translation.width))
                            let newH = max(75, min(300, minimapSize.height + v.translation.height))
                            minimapSize = CGSize(width: newW, height: newH)
                        }
                )
        }
        .onHover { hovering in
            opacityTask?.cancel()
            withAnimation(.easeInOut(duration: 0.2)) {
                visibleOpacity = hovering ? 0.9 : 0.4
            }
            if !hovering {
                opacityTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) { visibleOpacity = 0.4 }
                    }
                }
            }
        }
        .offset(miniMapOffset)
    }

    private func computeBounds() -> CGRect {
        guard let first = nodes.first else { return .zero }
        var rect = CGRect(origin: first.position, size: first.size)
        for node in nodes.dropFirst() {
            rect = rect.union(CGRect(origin: node.position, size: node.size))
        }
        return rect.insetBy(dx: -30, dy: -30)
    }
}
