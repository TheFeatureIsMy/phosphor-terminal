// CanvasBackground.swift — 画布背景网格
// 使用 SwiftUI Canvas 2D 上下文绘制点状网格

import SwiftUI

struct CanvasBackground: View {
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20
            let dotRadius: CGFloat = 1

            // Calculate visible range in world coordinates
            let startX = -offset.x / scale
            let startY = -offset.y / scale
            let endX = startX + size.width / scale
            let endY = startY + size.height / scale

            // Snap to grid
            let firstX = floor(startX / gridSize) * gridSize
            let firstY = floor(startY / gridSize) * gridSize

            var x = firstX
            while x <= endX {
                var y = firstY
                while y <= endY {
                    let screenPoint = CGPoint(
                        x: x * scale + offset.x,
                        y: y * scale + offset.y
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: screenPoint.x - dotRadius,
                            y: screenPoint.y - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        )),
                        with: .color(PulseColors.textMuted.opacity(0.3))
                    )
                    y += gridSize
                }
                x += gridSize
            }
        }
    }
}
