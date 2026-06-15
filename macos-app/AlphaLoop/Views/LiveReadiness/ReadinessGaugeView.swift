// ReadinessGaugeView.swift — Orbital readiness score

import SwiftUI

struct ReadinessGaugeView: View {
    @Environment(PulseColors.self) private var colors
    let score: Int

    @State private var animatedFraction: Double = 0
    @State private var orbitRotation: Double = 0
    @State private var glowPulse = false

    private let diameter: CGFloat = 220
    private let sweep: Double = 270
    private var fraction: Double { min(max(Double(score), 0), 100) / 100.0 }

    private var scoreColor: Color {
        if score >= 80 { return PulseColors.accent }
        if score >= 50 { return PulseColors.warning }
        return PulseColors.danger
    }

    var body: some View {
        ZStack {
            ambientGlow
            referenceRing
            trackArc
            fillArc
            tickMarks
            orbitingParticle
            scoreLabel
        }
        .frame(width: diameter * 1.4, height: diameter * 1.15)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) { animatedFraction = fraction }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .onChange(of: score) {
            withAnimation(.easeOut(duration: 0.8)) { animatedFraction = fraction }
        }
    }

    // MARK: - Layers

    private var ambientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [scoreColor.opacity(0.07), scoreColor.opacity(0.02), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.7
                )
            )
            .frame(width: diameter * 1.4, height: diameter * 1.4)
            .scaleEffect(glowPulse ? 1.06 : 1.0)
    }

    private var referenceRing: some View {
        Circle()
            .stroke(colors.border.opacity(0.1), lineWidth: 0.5)
            .frame(width: diameter + 30, height: diameter + 30)
    }

    private var trackArc: some View {
        SweepArc(start: -135, end: 135)
            .stroke(colors.border.opacity(0.15), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .frame(width: diameter, height: diameter)
    }

    private var fillArc: some View {
        SweepArc(start: -135, end: -135 + animatedFraction * sweep)
            .stroke(
                AngularGradient(
                    colors: [scoreColor.opacity(0.15), scoreColor.opacity(0.6), scoreColor],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 7, lineCap: .round)
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: scoreColor.opacity(0.3), radius: 8)
    }

    private var tickMarks: some View {
        ForEach(0..<11, id: \.self) { i in
            let angle = -135.0 + Double(i) * (sweep / 10.0)
            let isLit = Double(i) / 10.0 <= fraction
            let isMajor = i % 5 == 0

            Rectangle()
                .fill(isLit ? scoreColor.opacity(0.5) : colors.border.opacity(0.12))
                .frame(width: isMajor ? 1.5 : 0.5, height: isMajor ? 12 : 7)
                .offset(y: -(diameter / 2 + 16))
                .rotationEffect(.degrees(angle))
        }
    }

    private var orbitingParticle: some View {
        Circle()
            .fill(scoreColor)
            .frame(width: 3, height: 3)
            .shadow(color: scoreColor.opacity(0.8), radius: 4)
            .offset(y: -(diameter / 2 + 22))
            .rotationEffect(.degrees(orbitRotation))
            .opacity(0.6)
    }

    private var scoreLabel: some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(.system(size: 54, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())

            Text(L10n.LiveReadiness.readinessScore)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(3)
        }
    }
}

// MARK: - Arc Shape

private struct SweepArc: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(start - 90),
            endAngle: .degrees(end - 90),
            clockwise: false
        )
        return p
    }
}
