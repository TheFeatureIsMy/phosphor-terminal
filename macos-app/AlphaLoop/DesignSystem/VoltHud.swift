// VoltHud.swift — VOLT HUD 终端母题（级联全页的视觉签名）
// 1. TerminalGridBackground: 全局极淡网格 + 扫描线底纹，铺在内容区之下，
//    让每个页面共享同一块"终端面板"，而非纯黑空白。
// 2. VoltCorners: 卡片四角电光刻线（HUD 取景框），赋予卡片统一的终端身份。
// 3. VoltRule: 页头/区块下的电光发丝分隔线。

import SwiftUI

// MARK: - 全局终端网格底纹
struct TerminalGridBackground: View {
    @Environment(PulseColors.self) private var colors

    /// 网格步长
    var step: CGFloat = 44

    var body: some View {
        Canvas { ctx, size in
            // 纵向 + 横向发丝网格（极淡）
            let line = colors.textPrimary.opacity(0.025)
            var x: CGFloat = 0
            while x <= size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(line), lineWidth: 1)
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(line), lineWidth: 1)
                y += step
            }
            // 交叉节点微光点（更淡）
            let dot = PulseColors.accent.opacity(0.05)
            var dy: CGFloat = 0
            while dy <= size.height {
                var dx: CGFloat = 0
                while dx <= size.width {
                    let r = CGRect(x: dx - 1, y: dy - 1, width: 2, height: 2)
                    ctx.fill(Path(ellipseIn: r), with: .color(dot))
                    dx += step * 2
                }
                dy += step * 2
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 卡片四角电光刻线（HUD 取景框）
struct VoltCorners: View {
    var color: Color = PulseColors.accent.opacity(0.45)
    var length: CGFloat = 9
    var lineWidth: CGFloat = 1.5
    var inset: CGFloat = 4

    var body: some View {
        Canvas { ctx, size in
            let l = length
            let i = inset
            let w = size.width - i
            let h = size.height - i
            // 四个 L 形角
            let corners: [Path] = [
                corner(at: CGPoint(x: i, y: i), dx: 1, dy: 1, l: l),          // 左上
                corner(at: CGPoint(x: w, y: i), dx: -1, dy: 1, l: l),        // 右上
                corner(at: CGPoint(x: i, y: h), dx: 1, dy: -1, l: l),        // 左下
                corner(at: CGPoint(x: w, y: h), dx: -1, dy: -1, l: l),       // 右下
            ]
            for p in corners {
                ctx.stroke(p, with: .color(color), lineWidth: lineWidth)
            }
        }
        .allowsHitTesting(false)
    }

    private func corner(at pt: CGPoint, dx: CGFloat, dy: CGFloat, l: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: pt.x + dx * l, y: pt.y))
        p.addLine(to: CGPoint(x: pt.x, y: pt.y))
        p.addLine(to: CGPoint(x: pt.x, y: pt.y + dy * l))
        return p
    }
}

// MARK: - 电光发丝分隔线
struct VoltRule: View {
    var body: some View {
        LinearGradient(
            colors: [PulseColors.accent.opacity(0.5), PulseColors.accent.opacity(0.06), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 1)
    }
}
