// BentoEquityCard.swift — Bento 卡片: 账户总权益走势
import SwiftUI

struct BentoEquityCard: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    let points: [EquityPoint]

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        TerminalLabel(text: L10n.zh("账户总权益走势 (USDT)", en: "Total Equity Curve (USDT)"))

                        HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.xs) {
                            Text("124,850.32")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundStyle(colors.textPrimary)
                            Text("USDT")
                                .font(PulseFonts.captionMedium)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(KryptonColor.green)
                        Text("+2,415.80 (+1.95%)")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(KryptonColor.green)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, PulseSpacing.xs)
                    .padding(.vertical, 4)
                    .background(KryptonColor.green.opacity(0.1))
                    .clipShape(Capsule())
                }

                if points.isEmpty {
                    VStack {
                        Spacer()
                        Text(L10n.zh("等待权益曲线数据加载...", en: "Loading equity curve data..."))
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                        Spacer()
                    }
                    .frame(height: 180)
                } else {
                    EquityCurveChart(points: points)
                        .frame(height: 180)
                }
            }
        }
        .hoverEffect()
        .id(settingsState.language)
    }
}
