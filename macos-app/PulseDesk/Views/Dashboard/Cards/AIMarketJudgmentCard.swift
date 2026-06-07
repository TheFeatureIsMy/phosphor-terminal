// AIMarketJudgmentCard.swift — Bento 卡片: 今日 AI 市场判断
import SwiftUI

struct AIMarketJudgmentCard: View {
    @Environment(PulseColors.self) private var colors
    let judgment: AIMarketJudgment
    @State private var appeared = false

    var body: some View {
        KryptonCard(emphasis: .bold) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "今日 AI 市场判断")

                HStack(alignment: .center, spacing: PulseSpacing.md) {
                    directionIndicator
                    confidenceSlider
                }

                Text(judgment.reasoning)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(3)
                    .padding(PulseSpacing.xs)
                    .background(RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.surface.opacity(0.2)))
            }
        }
        .hoverEffect()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { appeared = true }
        }
    }

    private var directionIndicator: some View {
        VStack(spacing: PulseSpacing.xxs) {
            Text(judgment.direction)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(directionColor)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 4)
                .shadow(color: directionColor.opacity(0.3), radius: 8)

            Image(systemName: directionIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(directionColor)
        }
        .frame(width: 80)
        .padding(PulseSpacing.xs)
        .background(RoundedRectangle(cornerRadius: PulseRadii.md).fill(directionColor.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(directionColor.opacity(0.2), lineWidth: 1))
    }

    private var confidenceSlider: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                HStack {
                    Text("置信度 CONFIDENCE")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                    Spacer()
                    Text(String(format: "%.0f%%", judgment.confidence * 100))
                        .font(PulseFonts.tabular)
                        .foregroundStyle(directionColor)
                        .fontWeight(.bold)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(KryptonColor.background)
                            .frame(height: 6)
                            .overlay(RoundedRectangle(cornerRadius: PulseRadii.xs).stroke(colors.border, lineWidth: 0.5))

                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(LinearGradient(colors: [directionColor.opacity(0.5), directionColor], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(judgment.confidence), height: 6)
                            .shadow(color: directionColor.opacity(0.4), radius: 4)

                        Circle()
                            .fill(colors.textPrimary)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(directionColor, lineWidth: 2))
                            .shadow(color: directionColor, radius: 4)
                            .offset(x: geo.size.width * CGFloat(judgment.confidence) - 5, y: -2)
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: PulseSpacing.md) {
                BadgeDot(color: riskColor, label: riskLabel, size: .small)
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 8))
                        .foregroundStyle(colors.textMuted)
                    Text(judgment.sourceAgent.uppercased())
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }

    private var directionColor: Color {
        switch judgment.direction {
        case "看多": return KryptonColor.green
        case "看空": return KryptonColor.red
        default: return KryptonColor.amber
        }
    }

    private var directionIcon: String {
        switch judgment.direction {
        case "看多": return "arrow.up.right"
        case "看空": return "arrow.down.right"
        default: return "arrow.left.arrow.right"
        }
    }

    private var riskColor: Color {
        switch judgment.riskLevel {
        case "low": return KryptonColor.green
        case "high": return KryptonColor.amber
        case "critical": return KryptonColor.red
        default: return KryptonColor.amber
        }
    }

    private var riskLabel: String {
        switch judgment.riskLevel {
        case "low": return "低风险"
        case "high": return "高风险"
        case "critical": return "极高风险"
        default: return "中风险"
        }
    }
}
