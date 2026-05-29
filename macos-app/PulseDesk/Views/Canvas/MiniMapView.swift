// MiniMapView.swift — 画布右下角缩略图 (200x150)
// 显示所有节点为小色块 + 当前视口矩形，点击/拖拽可平移主画布

import SwiftUI

struct MiniMapView: View {
    let nodes: [CanvasNode]
    let viewport: ViewportState
    let canvasSize: CGSize
    var onPan: ((CGPoint) -> Void)?

    private let minimapSize = CGSize(width: 200, height: 150)

    var body: some View {
        Canvas { context, size in
            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: minimapSize)),
                with: .color(PulseColors.surface.opacity(0.85))
            )

            // Grid lines for visual depth
            let gridSpacing: CGFloat = 20
            for x in stride(from: 0, through: minimapSize.width, by: gridSpacing) {
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.addLine(to: CGPoint(x: x, y: minimapSize.height))
                context.stroke(gridPath, with: .color(PulseColors.border.opacity(0.3)), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: minimapSize.height, by: gridSpacing) {
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: minimapSize.width, y: y))
                context.stroke(gridPath, with: .color(PulseColors.border.opacity(0.3)), lineWidth: 0.5)
            }

            guard !nodes.isEmpty else { return }
            let bounds = computeBounds()
            let scaleX = minimapSize.width / max(bounds.width, 1)
            let scaleY = minimapSize.height / max(bounds.height, 1)
            let scale = min(scaleX, scaleY, 1.0)

            // Draw nodes as small colored rectangles
            for node in nodes {
                let def = NodeRegistry.definition(for: node.nodeType)
                let color = def?.category.color ?? PulseColors.textMuted
                let x = (node.position.x - bounds.minX) * scale
                let y = (node.position.y - bounds.minY) * scale
                let w = max(node.size.width * scale, 4)
                let h = max(node.size.height * scale, 3)
                let rect = CGRect(x: x, y: y, width: w, height: h)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1),
                    with: .color(color.opacity(0.7))
                )
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
                .stroke(PulseColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
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
