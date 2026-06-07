// FearGreedGauge.swift — 恐惧贪婪指数仪表盘

import SwiftUI

struct FearGreedGauge: View {
    @Environment(PulseColors.self) private var colors
    let index: Int  // 0-100
    let label: String

    private var gaugeColor: Color {
        switch index {
        case 0..<25: return PulseColors.danger
        case 25..<45: return PulseColors.warning
        case 45..<55: return colors.textMuted
        case 55..<75: return PulseColors.accent
        default: return PulseColors.success
        }
    }

    var body: some View {
        VStack(spacing: PulseSpacing.md) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(colors.surface, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(90))

                // Value arc
                Circle()
                    .trim(from: 0.25, to: 0.25 + 0.5 * Double(index) / 100.0)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(90))
                    .animation(.easeInOut(duration: 1), value: index)

                // Center value
                VStack(spacing: 2) {
                    Text("\(index)")
                        .font(PulseFonts.displayTitle)
                        .foregroundStyle(gaugeColor)
                    Text(label)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }

            // Scale labels
            HStack {
                Text("恐惧")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.danger)
                Spacer()
                Text("中性")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text("贪婪")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.success)
            }
            .frame(width: 140)
        }
    }
}
