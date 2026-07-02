// AtmosphericBackgroundModifier.swift — Shared atmospheric background for risk pages

import SwiftUI

struct RiskAtmosphericBackground: ViewModifier {
    let tint: Color
    @Environment(PulseColors.self) private var colors
    @State private var pulsePhase: Double = 0

    func body(content: Content) -> some View {
        ZStack {
            ZStack {
                colors.background

                RadialGradient(
                    colors: [
                        tint.opacity(0.08 + pulsePhase * 0.04),
                        tint.opacity(0.02),
                        Color.clear,
                    ],
                    center: .top,
                    startRadius: 50,
                    endRadius: 500
                )

                // Subtle scanline effect
                Canvas { context, size in
                    for y in stride(from: 0, to: size.height, by: 3) {
                        let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                        context.fill(Path(rect), with: .color(Color.white.opacity(0.008)))
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    pulsePhase = 1
                }
            }

            content
        }
    }
}

extension View {
    func riskAtmosphericBackground(tint: Color = PulseColors.accent) -> some View {
        modifier(RiskAtmosphericBackground(tint: tint))
    }
}
