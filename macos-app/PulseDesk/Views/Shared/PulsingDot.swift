// PulsingDot.swift — 脉动状态指示点

import SwiftUI

struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 8

    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulsing ? 1.5 : 1.0)
                .opacity(pulsing ? 0 : 0.5)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}
