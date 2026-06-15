// LaunchConsoleView.swift — Launch authorization command bar

import SwiftUI

struct LaunchConsoleView: View {
    @Environment(PulseColors.self) private var colors
    let blockingReasons: [[String: String]]
    let canStartPaper: Bool
    let canStartLiveSmall: Bool
    let canStartFullLive: Bool
    let onPaperTrade: () -> Void
    let onGoLive: () -> Void

    @State private var goLiveHover = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("▸")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(PulseColors.accent)
                TerminalLabel(text: L10n.LiveReadiness.launchSequence)
                Spacer()
            }
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.sm)

            Divider().background(colors.border.opacity(0.2))

            // Body: blockers + actions
            HStack(alignment: .center, spacing: 0) {
                // Left: Blockers
                blockerSection
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Separator
                Rectangle()
                    .fill(colors.border.opacity(0.2))
                    .frame(width: 0.5)
                    .padding(.vertical, PulseSpacing.xs)

                // Right: Actions
                actionButtons
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, PulseSpacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .fill(colors.surface.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.sm)
                .stroke(
                    canStartLiveSmall
                        ? PulseColors.accent.opacity(0.12)
                        : colors.border.opacity(0.2),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
    }

    // MARK: - Blockers

    private var blockerSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            if blockingReasons.isEmpty {
                HStack(spacing: PulseSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseColors.accent)
                    Text(L10n.LiveReadiness.allClear)
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                }
            } else {
                ForEach(Array(blockingReasons.enumerated()), id: \.offset) { _, reason in
                    HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.xs) {
                        Text("✗")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(PulseColors.danger)

                        Text(reason["code"] ?? "")
                            .font(PulseFonts.monoLabel)
                            .foregroundStyle(PulseColors.danger)

                        Text("— \(reason["message"] ?? "")")
                            .font(PulseFonts.micro)
                            .foregroundStyle(colors.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, PulseSpacing.md)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: PulseSpacing.sm) {
            Spacer()

            // Paper Trade
            Button(action: onPaperTrade) {
                Text(L10n.LiveReadiness.paperTrade)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, PulseSpacing.md)
                    .padding(.vertical, PulseSpacing.xs)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canStartPaper ? colors.textSecondary : colors.textMuted)
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(colors.border.opacity(canStartPaper ? 0.4 : 0.15), lineWidth: 1)
            )
            .disabled(!canStartPaper)
            .opacity(canStartPaper ? 1 : 0.4)

            // Go Live — primary action
            Button(action: onGoLive) {
                HStack(spacing: 4) {
                    Text(L10n.LiveReadiness.goLive)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, PulseSpacing.lg)
                .padding(.vertical, PulseSpacing.xs)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canStartLiveSmall ? PulseColors.accent : colors.textMuted)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .fill(canStartLiveSmall ? PulseColors.accent.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.xs)
                    .stroke(
                        canStartLiveSmall ? PulseColors.accent.opacity(0.35) : colors.border.opacity(0.15),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: canStartLiveSmall ? PulseColors.accent.opacity(0.15) : .clear, radius: 8)
            .disabled(!canStartLiveSmall)
            .opacity(canStartLiveSmall ? 1 : 0.4)

            // Full Live (locked)
            Text(L10n.LiveReadiness.fullLive)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(colors.textMuted)
                .padding(.horizontal, PulseSpacing.md)
                .padding(.vertical, PulseSpacing.xs)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.xs)
                        .stroke(colors.border.opacity(0.1), lineWidth: 1)
                )
                .opacity(canStartFullLive ? 0.8 : 0.25)

            Spacer()
        }
        .padding(.horizontal, PulseSpacing.sm)
    }
}
