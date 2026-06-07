// BackgroundLayersView.swift — Krypton 深色金融终端背景

import SwiftUI

struct BackgroundLayersView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            ambientGlow
            dotGridOverlay
            scanlineOverlay
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var ambientGlow: some View {
        ZStack {
            RadialGradient(
                colors: [KryptonColor.amberSpotlight, .clear],
                center: .init(x: 0.12, y: 0.08),
                startRadius: 0,
                endRadius: 620
            )
            .opacity(themeManager.isDark ? 0.85 : 0.35)

            RadialGradient(
                colors: [KryptonColor.greenSoft, .clear],
                center: .init(x: 0.86, y: 0.86),
                startRadius: 0,
                endRadius: 520
            )
            .opacity(themeManager.isDark ? 0.45 : 0.2)

            RadialGradient(
                colors: [KryptonColor.redSoft, .clear],
                center: .init(x: 0.5, y: 0.48),
                startRadius: 0,
                endRadius: 420
            )
            .opacity(themeManager.isDark ? 0.22 : 0.08)
        }
    }

    private var scanlineOverlay: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 4
            let opacity = themeManager.isDark ? 0.01 : 0.006
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(opacity)))
                y += lineSpacing
            }
        }
    }

    private var dotGridOverlay: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let dotRadius: CGFloat = 0.45
            let opacity = themeManager.isDark ? 0.025 : 0.012
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(opacity)))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}
