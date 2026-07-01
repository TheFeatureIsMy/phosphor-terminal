// LifecycleTimeline.swift — §2 水平 5 节点生命周期时间线

import SwiftUI

struct LifecycleTimeline: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.lifecycleTimeline)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(LifecycleStagePalette.stages.enumerated()), id: \.offset) { idx, stage in
                        TimelineNode(
                            stage: stage,
                            isCurrent: stage == detail.lifecycleStage,
                            isPast: isPast(stage),
                            entry: detail.timeline.first { $0.stage == stage }
                        )
                        if idx < LifecycleStagePalette.stages.count - 1 {
                            TimelineConnector(isActive: isPast(stage) || stage == detail.lifecycleStage)
                        }
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }

    private func isPast(_ stage: String) -> Bool {
        guard let currentIdx = LifecycleStagePalette.stages.firstIndex(of: detail.lifecycleStage),
              let idx = LifecycleStagePalette.stages.firstIndex(of: stage) else { return false }
        return idx < currentIdx
    }
}

private struct TimelineNode: View {
    let stage: String
    let isCurrent: Bool
    let isPast: Bool
    let entry: ManipulationStageEntry?
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: PulseSpacing.xs) {
            ZStack {
                Circle()
                    .fill(isCurrent || isPast ? LifecycleStagePalette.color(stage, colors: colors) : Color.clear)
                    .frame(width: isCurrent ? 28 : 22, height: isCurrent ? 28 : 22)
                if !isCurrent && !isPast {
                    Circle().strokeBorder(LifecycleStagePalette.color(stage, colors: colors).opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .frame(width: 22, height: 22)
                }
                Image(systemName: LifecycleStagePalette.icon(stage))
                    .font(PulseFonts.micro)
                    .foregroundStyle(isCurrent || isPast ? colors.background : colors.textMuted)
            }
            Text(stage.uppercased())
                .font(PulseFonts.micro)
                .foregroundStyle(isCurrent ? PulseColors.accent : colors.textMuted)
            if let entry = entry {
                Text(entry.enteredAt.prefix(10))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineConnector: View {
    let isActive: Bool
    @Environment(PulseColors.self) private var colors
    var body: some View {
        Rectangle()
            .fill(isActive ? PulseColors.accent.opacity(0.6) : colors.border)
            .frame(height: 2)
            .padding(.top, 13)
    }
}
