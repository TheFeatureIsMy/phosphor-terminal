// StrategyLifecycleRailView.swift — Strategy Version Lifecycle Rail §5.2

import SwiftUI

struct StrategyLifecycleRailView: View {
    @Environment(PulseColors.self) private var colors
    let currentStatus: String

    private let stages: [(key: String, label: String, icon: String)] = [
        ("draft", "Draft", "doc.text"),
        ("validated", "Validated", "checkmark.shield"),
        ("backtested", "Backtested", "chart.line.uptrend.xyaxis"),
        ("paper_running", "Paper Run", "play.circle"),
        ("paper_passed", "Paper ✓", "checkmark.circle"),
        ("live_pending", "Live审批", "person.badge.clock"),
        ("live_small", "Live Small", "bolt.circle"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(PulseColors.accent)
                    .font(.system(size: 12))
                Text(L10n.zh("版本生命周期", en: "Version Lifecycle"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.element.key) { index, stage in
                        let state = stageState(stage.key)
                        HStack(spacing: 0) {
                            stageNode(stage: stage, state: state)
                            if index < stages.count - 1 {
                                stageConnector(state: state)
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseSpacing.xs)
            }
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(colors.border, lineWidth: 1)
                )
        )
    }

    private enum StageState {
        case completed, current, upcoming
    }

    private func stageState(_ key: String) -> StageState {
        let currentIndex = stages.firstIndex(where: { $0.key == currentStatus }) ?? 0
        let stageIndex = stages.firstIndex(where: { $0.key == key }) ?? 0
        if stageIndex < currentIndex { return .completed }
        if stageIndex == currentIndex { return .current }
        return .upcoming
    }

    @ViewBuilder
    private func stageNode(stage: (key: String, label: String, icon: String), state: StageState) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(stageColor(state).opacity(state == .current ? 0.15 : 0.06))
                    .frame(width: 28, height: 28)
                Image(systemName: state == .completed ? "checkmark" : stage.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(stageColor(state))
            }
            Text(stage.label)
                .font(PulseFonts.micro)
                .foregroundStyle(state == .upcoming ? colors.textMuted : colors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 64)
    }

    private func stageConnector(state: StageState) -> some View {
        Rectangle()
            .fill(state == .completed ? PulseColors.accent.opacity(0.4) : colors.border)
            .frame(width: 16, height: 1.5)
            .offset(y: -8)
    }

    private func stageColor(_ state: StageState) -> Color {
        switch state {
        case .completed: PulseColors.accent
        case .current: PulseColors.cyan
        case .upcoming: colors.textMuted
        }
    }
}
