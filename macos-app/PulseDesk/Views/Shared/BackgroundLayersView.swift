// BackgroundLayersView.swift — ProofAlpha 背景层（双主题支持）
// Mesh gradient + 扫描线 + 点阵网格 + 噪点纹理

import SwiftUI

struct BackgroundLayersView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            meshGradient
            scanlineOverlay
            dotGridOverlay
            noiseOverlay
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var meshGradient: some View {
        ZStack {
            if themeManager.isDark {
                // 暗黑模式：绿色 + 琥珀 + 青色 + 紫色光晕
                RadialGradient(colors: [PulseColors.accent.opacity(0.08), .clear], center: .init(x: 0.1, y: 0.1), startRadius: 0, endRadius: 600)
                RadialGradient(colors: [PulseColors.warning.opacity(0.06), .clear], center: .init(x: 0.85, y: 0.85), startRadius: 0, endRadius: 500)
                RadialGradient(colors: [PulseColors.cyan.opacity(0.04), .clear], center: .init(x: 0.5, y: 0.4), startRadius: 0, endRadius: 450)
                RadialGradient(colors: [PulseColors.purple.opacity(0.03), .clear], center: .init(x: 0.8, y: 0.15), startRadius: 0, endRadius: 350)
            } else {
                // 明亮模式：更淡的彩色光晕
                RadialGradient(colors: [PulseColors.accent.opacity(0.04), .clear], center: .init(x: 0.1, y: 0.1), startRadius: 0, endRadius: 600)
                RadialGradient(colors: [PulseColors.warning.opacity(0.03), .clear], center: .init(x: 0.85, y: 0.85), startRadius: 0, endRadius: 500)
                RadialGradient(colors: [PulseColors.cyan.opacity(0.025), .clear], center: .init(x: 0.5, y: 0.4), startRadius: 0, endRadius: 450)
            }
        }
    }

    private var scanlineOverlay: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 4
            let opacity = themeManager.isDark ? 0.008 : 0.004
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(opacity)))
                y += lineSpacing
            }
        }
    }

    private var dotGridOverlay: some View {
        Canvas { context, size in
            let spacing: CGFloat = 60
            let dotRadius: CGFloat = 0.5
            let opacity = themeManager.isDark ? 0.03 : 0.02
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(.black.opacity(opacity)))
                    y += spacing
                }
                x += spacing
            }
        }
    }

    private var noiseOverlay: some View {
        Canvas { context, size in
            let step: CGFloat = 5
            let opacity = themeManager.isDark ? 0.025 : 0.012
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let hash = Int(x * 7 + y * 13) % 100
                    if hash < 8 {
                        context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.black.opacity(opacity)))
                    }
                    y += step
                }
                x += step
            }
        }
        .opacity(0.3)
    }
}
