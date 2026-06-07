// CanvasSelectionRect.swift — 框选矩形覆盖层
// 显示用户在画布上拖拽出的选择区域

import SwiftUI

struct CanvasSelectionRect: View {
    let rect: CGRect

    var body: some View {
        Canvas { context, size in
            let path = Path(rect)
            context.fill(path, with: .color(PulseColors.accent.opacity(0.1)))
            context.stroke(path, with: .color(PulseColors.accent.opacity(0.5)), lineWidth: 1)
        }
    }
}
