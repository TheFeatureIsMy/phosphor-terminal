// CaseCardView.swift — 操纵案例卡片 (ManipulationCaseSummary)
// Compact card for radar overview grid: symbol + type chip, lifecycle indicator, confidence bar + signal badge

import SwiftUI

struct CaseCardView: View {
    @Environment(PulseColors.self) private var colors

    let caseSummary: ManipulationCaseSummary

    var body: some View {
        KryptonCard(emphasis: .balanced) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // MARK: Top row — symbol + manipulation type badge
                topRow

                // MARK: Middle — lifecycle stage indicator
                LifecycleIndicator(currentStage: caseSummary.lifecycleStage)

                // MARK: Bottom row — confidence bar + trading signal badge
                bottomRow
            }
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(spacing: PulseSpacing.sm) {
            Text(caseSummary.symbol)
                .font(PulseFonts.bodyMedium)
                .bold()
                .foregroundStyle(colors.textPrimary)

            Spacer()

            typeChip
        }
    }

    // MARK: - Type Chip (M1–M8)

    private var typeChip: some View {
        let typeKey = caseSummary.manipulationType.uppercased()
        let color = typeColor(typeKey)

        return Text(typeKey)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: PulseRadii.badge))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(spacing: PulseSpacing.sm) {
            // Confidence bar
            confidenceBar

            Spacer()

            // Trading signal action badge
            signalBadge
        }
    }

    // MARK: - Confidence Bar

    private var confidenceBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: PulseSpacing.xxs) {
                Text(L10n.Manipulation.confidence)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                Spacer()
                Text(String(format: "%.0f%%", caseSummary.confidence * 100))
                    .font(PulseFonts.micro)
                    .foregroundStyle(confidenceColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.surface)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(confidenceColor)
                        .frame(width: geo.size.width * min(caseSummary.confidence, 1.0), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var confidenceColor: Color {
        let pct = caseSummary.confidence * 100
        if pct > 70 { return PulseColors.danger }
        if pct > 40 { return PulseColors.amber }
        return PulseColors.success
    }

    // MARK: - Signal Badge

    private var signalBadge: some View {
        let action = caseSummary.tradingSignalAction.uppercased()
        let label = signalLabel(action)
        let color = signalColor(action)

        return BadgeDot(color: color, label: label, size: .small)
    }

    // MARK: - Signal Label (localized)

    private func signalLabel(_ action: String) -> String {
        switch action {
        case "AMBUSH":                        return L10n.Manipulation.signalAmbush
        case "RIDE":                          return L10n.Manipulation.signalRide
        case "EXIT":                          return L10n.Manipulation.signalExit
        case "EXIT/SHORT", "EXIT_OR_SHORT":   return L10n.Manipulation.signalExitOrShort
        case "AVOID":                         return L10n.Manipulation.signalAvoid
        case "WATCH":                         return L10n.Manipulation.signalWatch
        case "CAUTION":                       return L10n.Manipulation.signalCaution
        default:                              return action
        }
    }

    // MARK: - Color Helpers

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "M1", "M2": return PulseColors.purple
        case "M3", "M4": return PulseColors.cyan
        case "M5":       return PulseColors.danger
        case "M6", "M7": return PulseColors.warning
        case "M8":       return PulseColors.danger
        default:         return colors.textMuted
        }
    }

    private func signalColor(_ action: String) -> Color {
        switch action {
        case "AMBUSH", "RIDE":                          return PulseColors.accent
        case "EXIT", "EXIT/SHORT", "EXIT_OR_SHORT", "AVOID": return PulseColors.danger
        case "WATCH", "CAUTION":                        return PulseColors.warning
        default:                                        return colors.textMuted
        }
    }
}
