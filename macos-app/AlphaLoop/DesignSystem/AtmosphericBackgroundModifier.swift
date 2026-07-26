// AtmosphericBackgroundModifier.swift — Protocol 浅色页面背景(冷白纯色,无扫描线/脉冲)

import SwiftUI

struct RiskAtmosphericBackground: ViewModifier {
    let tint: Color
    @Environment(PulseColors.self) private var colors

    func body(content: Content) -> some View {
        ZStack {
            // Protocol §③: 冷白纯色底,零渐变/扫描线。
            colors.background
                .ignoresSafeArea()

            content
        }
    }
}

extension View {
    func riskAtmosphericBackground(tint: Color = PulseColors.accent) -> some View {
        modifier(RiskAtmosphericBackground(tint: tint))
    }
}
