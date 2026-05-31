// KPICardView.swift — ProofAlpha KPI 指标卡片
// GlassCard 统一样式

import SwiftUI

struct KPICardView: View {
    @Environment(PulseColors.self) private var colors
    let icon: String
    let label: String
    let value: String
    let trend: Double?
    let color: Color

    @State private var appeared = false
    @State private var isHovered = false

    var body: some View {
        GlassCard(cardPadding: PulseSpacing.xs) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                    TerminalLabel(text: label)
                }

                Text(value)
                    .font(PulseFonts.tabularLarge)
                    .foregroundStyle(colors.textPrimary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 4)
                    .shadow(color: isHovered ? PulseColors.accent.opacity(0.15) : .clear, radius: 8)

                HStack(spacing: 3) {
                    if let trend {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text(String(format: "%+.1f%%", trend))
                            .font(PulseFonts.monoLabel)
                            .staggeredAppearance(index: 1, baseDelay: 0.1)
                    } else {
                        Text("—")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(colors.textMuted)
                    }
                }
                .foregroundStyle(trend != nil ? (trend! >= 0 ? colors.profit : colors.loss) : colors.textMuted)
                .frame(height: 14)
            }
        }
        .frame(minHeight: 90)
        .onHover { isHovered = $0 }
        .onAppear {
            withAnimation(PulseAnimation.springDefault.delay(0.1)) {
                appeared = true
            }
        }
    }
}
