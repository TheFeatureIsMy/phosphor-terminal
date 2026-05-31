// CanvasDragPreview.swift — 连线拖拽预览
// 从输出端口到当前光标的虚线贝塞尔曲线

import SwiftUI

struct CanvasDragPreview: View {
    let sourcePoint: CGPoint
    let currentPoint: CGPoint
    let color: Color
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            let from = CGPoint(x: sourcePoint.x * scale + offset.x, y: sourcePoint.y * scale + offset.y)
            let to = CGPoint(x: currentPoint.x * scale + offset.x, y: currentPoint.y * scale + offset.y)

            let dx = abs(to.x - from.x) * 0.5
            var path = Path()
            path.move(to: from)
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x + dx, y: from.y),
                control2: CGPoint(x: to.x - dx, y: to.y)
            )
            context.stroke(path, with: .color(color.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
    }
}
