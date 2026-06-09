// ShadowStrategySuggestionsPanel.swift — Shadow Strategy Suggestions §7.2

import SwiftUI

struct ShadowStrategySuggestionsPanel: View {
    @Environment(PulseColors.self) private var colors
    let drafts: [ShadowStrategyDraftResponse]
    var onSelect: ((ShadowStrategyDraftResponse) -> Void)?
    var onValidate: ((String) -> Void)?
    var onRequestUpgrade: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(PulseColors.cyan)
                Text(L10n.zh("影子策略建议", en: "Shadow Strategy Suggestions"))
                    .font(PulseFonts.label)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Text("\(drafts.count)")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textMuted)
            }

            if drafts.isEmpty {
                Text(L10n.zh("暂无影子策略建议。从失败聚类中生成。", en: "No shadow strategies yet. Generate from failure clusters."))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, PulseSpacing.sm)
            } else {
                ForEach(drafts) { draft in
                    draftRow(draft)
                }
            }
        }
        .padding(PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.card)
                        .stroke(colors.border, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func draftRow(_ draft: ShadowStrategyDraftResponse) -> some View {
        Button { onSelect?(draft) } label: {
            HStack(spacing: PulseSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.title)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(draft.statusLabel)
                            .font(PulseFonts.micro)
                            .foregroundStyle(draftStatusColor(draft.status))
                        if let pattern = draft.failurePattern, let count = pattern.sampleSize {
                            Text("• \(count) trades")
                                .font(PulseFonts.micro)
                                .foregroundStyle(colors.textMuted)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, PulseSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(colors.cardBackground.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private func draftStatusColor(_ status: String) -> Color {
        switch status {
        case "approved", "merged_to_strategy_version": PulseColors.accent
        case "validated", "backtested", "dryrun_passed": PulseColors.cyan
        case "human_review": PulseColors.amber
        case "rejected": PulseColors.danger
        default: colors.textMuted
        }
    }
}
