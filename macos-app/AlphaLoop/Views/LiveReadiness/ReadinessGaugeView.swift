import SwiftUI

struct ReadinessGaugeView: View {
    @Environment(PulseColors.self) private var colors
    let score: Int

    private let arcStart: Double = 0.65  // start angle (bottom-left)
    private let arcEnd: Double = 0.35    // end angle (bottom-right) — 270° sweep

    private var scoreColor: Color {
        if score >= 80 { return PulseColors.accent }
        if score >= 50 { return PulseColors.warning }
        return PulseColors.danger
    }

    private var needleAngle: Double {
        // Map score 0-100 to angle range
        let fraction = min(max(Double(score), 0), 100) / 100.0
        return -135 + (fraction * 270) // -135° to +135° sweep
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track arc
                ArcShape(startAngle: -135, endAngle: 135)
                    .stroke(colors.border, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 100, height: 100)

                // Fill arc
                ArcShape(startAngle: -135, endAngle: needleAngle)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .shadow(color: scoreColor.opacity(0.3), radius: 4)

                // Needle
                Rectangle()
                    .fill(
                        LinearGradient(colors: [scoreColor, scoreColor.opacity(0.3)],
                                       startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: 2, height: 40)
                    .offset(y: -20)
                    .rotationEffect(.degrees(needleAngle))

                // Center knob
                Circle()
                    .fill(scoreColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: scoreColor.opacity(0.5), radius: 4)

                // Score number (positioned below center)
                VStack(spacing: 2) {
                    Spacer()
                    Text("\(score)")
                        .font(PulseFonts.tabularLarge)
                        .foregroundStyle(scoreColor)
                    Text(L10n.LiveReadiness.readinessScore)
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
                .frame(width: 100, height: 100)
                .padding(.bottom, 4)
            }
            .frame(width: 120, height: 80)
            .clipped()
        }
    }
}

// Half-circle arc shape
private struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(startAngle - 90),
                    endAngle: .degrees(endAngle - 90),
                    clockwise: false)
        return path
    }
}
