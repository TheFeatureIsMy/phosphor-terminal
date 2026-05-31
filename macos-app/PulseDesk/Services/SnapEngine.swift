import Foundation

struct SnapResult {
    let snappedPosition: CGPoint
    let guides: [SnapGuide]
}

struct SnapGuide {
    let position: CGFloat
    let orientation: Orientation
    enum Orientation { case horizontal, vertical }
}

struct SnapEngine {
    let threshold: CGFloat = 8
    let gridSize: CGFloat = 20

    func snap(
        position: CGPoint,
        size: CGSize,
        otherNodes: [CanvasNode],
        excludeId: UUID? = nil,
        useGrid: Bool = false
    ) -> SnapResult {
        var pos = position
        var guides: [SnapGuide] = []

        let cx = pos.x + size.width / 2
        let cy = pos.y + size.height / 2
        let left = pos.x
        let right = pos.x + size.width
        let top = pos.y
        let bottom = pos.y + size.height

        for other in otherNodes {
            if let excludeId, other.id == excludeId { continue }

            checkSnap(value: left, against: other.position.x, threshold: threshold) { snapped in
                pos.x = snapped; guides.append(SnapGuide(position: other.position.x, orientation: .vertical))
            }
            checkSnap(value: right, against: other.position.x + other.size.width, threshold: threshold) { snapped in
                pos.x = snapped - size.width; guides.append(SnapGuide(position: other.position.x + other.size.width, orientation: .vertical))
            }
            checkSnap(value: top, against: other.position.y, threshold: threshold) { snapped in
                pos.y = snapped; guides.append(SnapGuide(position: other.position.y, orientation: .horizontal))
            }
            checkSnap(value: bottom, against: other.position.y + other.size.height, threshold: threshold) { snapped in
                pos.y = snapped - size.height; guides.append(SnapGuide(position: other.position.y + other.size.height, orientation: .horizontal))
            }
            checkSnap(value: cx, against: other.position.x + other.size.width / 2, threshold: threshold) { snapped in
                pos.x = snapped - size.width / 2; guides.append(SnapGuide(position: other.position.x + other.size.width / 2, orientation: .vertical))
            }
            checkSnap(value: cy, against: other.position.y + other.size.height / 2, threshold: threshold) { snapped in
                pos.y = snapped - size.height / 2; guides.append(SnapGuide(position: other.position.y + other.size.height / 2, orientation: .horizontal))
            }
        }

        if useGrid {
            let gridX = round(pos.x / gridSize) * gridSize
            let gridY = round(pos.y / gridSize) * gridSize
            if abs(pos.x - gridX) < threshold { pos.x = gridX }
            if abs(pos.y - gridY) < threshold { pos.y = gridY }
        }

        return SnapResult(snappedPosition: pos, guides: guides)
    }

    private func checkSnap(value: CGFloat, against target: CGFloat, threshold: CGFloat, onSnap: (CGFloat) -> Void) {
        if abs(value - target) < threshold {
            onSnap(target)
        }
    }
}
