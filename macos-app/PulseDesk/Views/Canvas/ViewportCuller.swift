import Foundation

struct ViewportCuller {
    let padding: CGFloat = 200

    func visibleNodes(
        _ nodes: [CanvasNode],
        selectedIds: Set<UUID>,
        viewport: ViewportState,
        canvasSize: CGSize
    ) -> [CanvasNode] {
        let visibleRect = worldVisibleRect(viewport: viewport, canvasSize: canvasSize)
            .insetBy(dx: -padding, dy: -padding)

        var result = nodes.filter { node in
            let nodeRect = CGRect(
                x: node.position.x,
                y: node.position.y,
                width: node.size.width,
                height: node.size.height
            )
            return visibleRect.intersects(nodeRect)
        }

        // Always include selected nodes even if outside visible rect
        for node in nodes {
            if selectedIds.contains(node.id) && !result.contains(where: { $0.id == node.id }) {
                result.append(node)
            }
        }

        return result
    }

    private func worldVisibleRect(viewport: ViewportState, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: -viewport.offset.x / viewport.scale,
            y: -viewport.offset.y / viewport.scale,
            width: canvasSize.width / viewport.scale,
            height: canvasSize.height / viewport.scale
        )
    }
}
