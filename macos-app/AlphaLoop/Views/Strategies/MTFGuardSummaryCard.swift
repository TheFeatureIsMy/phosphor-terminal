// MTFGuardSummaryCard.swift — MTF Temporal Guard Summary §6.2

import SwiftUI

struct MTFGuardSummaryCard: View {
    @Environment(PulseColors.self) private var colors
    let guards: [MTFGuardInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .foregroundStyle(PulseColors.cyan)
                    .font(.system(size: 12))
                Text(L10n.zh("MTF 防御状态", en: "MTF Guard Status"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Text("\(guards.count)")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(colors.textMuted)
            }

            if guards.isEmpty {
                Text(L10n.zh("暂无 MTF Guard 配置", en: "No MTF Guard configured"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, PulseSpacing.xs)
            } else {
                VStack(spacing: PulseSpacing.xs) {
                    ForEach(guards) { guard_ in
                        guardRow(guard_)
                    }
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
    private func guardRow(_ info: MTFGuardInfo) -> some View {
        HStack(spacing: PulseSpacing.sm) {
            Circle()
                .fill(guardColor(info.guardState))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(info.fastTimeframe)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(colors.textMuted)
                    Text(info.slowTimeframe)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                }
                Text(info.structureType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(info.stateLabel)
                    .font(PulseFonts.micro)
                    .foregroundStyle(guardColor(info.guardState))
                Text(info.actionLabel)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }

            if !info.reasonCodes.isEmpty {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textMuted)
                    .help(info.reasonCodes.joined(separator: "\n"))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, PulseSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(guardColor(info.guardState).opacity(0.04))
        )
    }

    private func guardColor(_ state: String) -> Color {
        switch state {
        case "confirmed": PulseColors.accent
        case "watching", "pending_htf_close", "reclaim_pending": PulseColors.amber
        case "temporary_violation": PulseColors.warning
        case "invalidated": PulseColors.danger
        case "expired": colors.textMuted
        default: colors.textMuted
        }
    }
}
