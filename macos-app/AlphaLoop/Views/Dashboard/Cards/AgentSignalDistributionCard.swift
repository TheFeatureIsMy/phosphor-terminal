// AgentSignalDistributionCard.swift — Bento 卡片: Agent 信号分布
import SwiftUI

struct AgentSignalDistributionCard: View {
    @Environment(PulseColors.self) private var colors
    let groups: [AgentSignalGroup]

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                TerminalLabel(text: "Agent 信号分布")

                if groups.isEmpty {
                    Text("暂无信号数据")
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .padding(.vertical, PulseSpacing.sm)
                } else {
                    VStack(spacing: PulseSpacing.xs) {
                        ForEach(groups) { group in
                            agentSignalRow(group)
                        }
                    }

                    HStack(spacing: PulseSpacing.md) {
                        HStack(spacing: 4) {
                            Circle().fill(KryptonColor.green).frame(width: 5, height: 5)
                            Text("BULLISH 多").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(KryptonColor.red).frame(width: 5, height: 5)
                            Text("BEARISH 空").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .hoverEffect()
    }

    private func agentSignalRow(_ group: AgentSignalGroup) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Text(group.agentName.uppercased())
                .font(PulseFonts.monoLabel)
                .foregroundStyle(colors.textPrimary)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                let total = max(group.signalCount, 1)
                let longPct = CGFloat(group.longCount) / CGFloat(total)
                let shortPct = CGFloat(group.shortCount) / CGFloat(total)

                HStack(spacing: 1) {
                    if group.longCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KryptonColor.green)
                            .frame(width: max(geo.size.width * longPct - 0.5, 0), height: 10)
                            .shadow(color: KryptonColor.green.opacity(0.3), radius: 2)
                    }
                    if group.shortCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KryptonColor.red)
                            .frame(width: max(geo.size.width * shortPct - 0.5, 0), height: 10)
                            .shadow(color: KryptonColor.red.opacity(0.3), radius: 2)
                    }
                }
            }
            .frame(height: 10)

            HStack(spacing: 4) {
                Text("\(group.longCount)多").font(PulseFonts.micro).foregroundStyle(KryptonColor.green)
                Text("/").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Text("\(group.shortCount)空").font(PulseFonts.micro).foregroundStyle(KryptonColor.red)
            }
            .frame(width: 60, alignment: .trailing)
        }
    }
}
