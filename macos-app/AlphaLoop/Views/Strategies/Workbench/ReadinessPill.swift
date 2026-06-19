// ReadinessPill.swift — workbench HUD readiness chip (N/11 + grandStatus color).
// Spec §5.1 / §6.4 — color comes from grand_status:
//   ready_for_live → accent  ·  paper_passed → cyan/info  ·
//   needs_validation/needs_config → amber  ·  not_live → muted/danger.
import SwiftUI

struct ReadinessPill: View {
    let passedCount: Int
    var total: Int = 11
    let grandStatus: String

    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(L10n.Workbench.hudReadinessLabel)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(colors.textMuted)

            Text("\(passedCount)/\(total)")
                .font(PulseFonts.tabular)
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch grandStatus {
        case "ready_for_live":     return PulseColors.accent
        case "paper_passed":       return PulseColors.info
        case "needs_validation",
             "needs_config":       return PulseColors.amber
        case "not_live":           return PulseColors.danger
        default:                   return colors.textMuted
        }
    }

    private var borderColor: Color {
        switch grandStatus {
        case "ready_for_live":     return PulseColors.accent.opacity(0.30)
        case "paper_passed":       return PulseColors.info.opacity(0.30)
        case "needs_validation",
             "needs_config":       return PulseColors.amber.opacity(0.30)
        case "not_live":           return PulseColors.danger.opacity(0.30)
        default:                   return colors.border
        }
    }
}
