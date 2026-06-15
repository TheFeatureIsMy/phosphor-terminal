// ReadinessGaugeView.swift — Countdown-ring readiness score (editorial style)

import SwiftUI

struct ReadinessGaugeView: View {
    @Environment(PulseColors.self) private var colors
    let score: Int

    @State private var animatedProgress: Double = 0
    @State private var glowPulse = false

    private let ringSize: CGFloat = 180
    private let strokeWidth: CGFloat = 6
    private var fraction: Double { min(max(Double(score), 0), 100) / 100.0 }

    private var scoreColor: Color {
        if score >= 80 { return PulseColors.accent }
        if score >= 50 { return PulseColors.warning }
        return PulseColors.danger
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(colors.border.opacity(0.3), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: ringSize, height: ringSize)

            // Score arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(scoreColor.opacity(0.9), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .shadow(color: scoreColor.opacity(glowPulse ? 0.3 : 0.15), radius: 8)

            // Center content
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(scoreColor)
                    .contentTransition(.numericText())

                Text(L10n.LiveReadiness.readinessScore)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .frame(width: ringSize + 24, height: ringSize + 24)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { animatedProgress = fraction }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { glowPulse = true }
        }
        .onChange(of: score) {
            withAnimation(.easeOut(duration: 0.8)) { animatedProgress = fraction }
        }
    }
}
