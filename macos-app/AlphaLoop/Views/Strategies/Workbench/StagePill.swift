// StagePill.swift — 7-segment lifecycle progress for the workbench HUD.
// Spec §5.1: text "Stage 5/7" + 7×4px bar mapping LifecycleStage.from(status).
import SwiftUI

struct StagePill: View {
    let currentStatus: String

    @Environment(PulseColors.self) private var colors

    private var stage: LifecycleStage { LifecycleStage.from(status: currentStatus) }
    private var offPath: LifecycleOffPath? { LifecycleOffPath.from(status: currentStatus) }
    private var totalSteps: Int { LifecycleStage.allCases.count }
    private var passedSteps: Int { stage.rawValue + 1 }

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.Workbench.hudStageLabel)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textMuted)

            Text("\(passedSteps)/\(totalSteps)")
                .font(PulseFonts.tabular)
                .foregroundStyle(colors.textPrimary)

            HStack(spacing: 2) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(barColor(at: i))
                        .frame(width: 12, height: 4)
                }
            }

            if let off = offPath {
                Image(systemName: off.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PulseColors.amber)
                    .help(off.label)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(colors.border, lineWidth: 1)
        )
    }

    private func barColor(at index: Int) -> Color {
        if index < passedSteps {
            return offPath == nil ? PulseColors.accent : PulseColors.amber
        }
        return colors.border
    }
}
