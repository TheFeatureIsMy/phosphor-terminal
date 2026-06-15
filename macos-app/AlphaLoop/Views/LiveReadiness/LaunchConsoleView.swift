import SwiftUI

struct LaunchConsoleView: View {
    @Environment(PulseColors.self) private var colors
    let blockingReasons: [[String: String]]
    let canStartPaper: Bool
    let canStartLiveSmall: Bool
    let canStartFullLive: Bool
    let onPaperTrade: () -> Void
    let onGoLive: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PulseColors.accent)
                    TerminalLabel(text: L10n.LiveReadiness.launchSequence)
                }
                Spacer()
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.vertical, PulseSpacing.sm)
            .background(colors.surfaceElevated)

            Divider().background(colors.border)

            HStack(alignment: .top, spacing: 0) {
                // Left: Blockers
                VStack(alignment: .leading, spacing: 4) {
                    if blockingReasons.isEmpty {
                        Text("All clear")
                            .font(PulseFonts.caption)
                            .foregroundStyle(PulseColors.accent)
                            .padding(.vertical, PulseSpacing.xs)
                    } else {
                        ForEach(Array(blockingReasons.enumerated()), id: \.offset) { _, reason in
                            HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.xs) {
                                Text("✗")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(PulseColors.danger)

                                Text(reason["code"] ?? "")
                                    .font(PulseFonts.monoLabel)
                                    .foregroundStyle(PulseColors.danger)

                                Text("— \(reason["message"] ?? "")")
                                    .font(PulseFonts.caption)
                                    .foregroundStyle(colors.textMuted)
                            }
                        }
                    }
                }
                .frame(maxWidth: 380, alignment: .leading)
                .padding(PulseSpacing.md)

                // Divider
                Rectangle()
                    .fill(colors.border)
                    .frame(width: 1)
                    .padding(.vertical, PulseSpacing.sm)

                // Right: Action buttons
                HStack(spacing: PulseSpacing.md) {
                    Spacer()

                    // Paper Trade
                    Button(action: onPaperTrade) {
                        Text(L10n.LiveReadiness.paperTrade)
                            .font(PulseFonts.monoLabel)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, PulseSpacing.lg)
                            .padding(.vertical, PulseSpacing.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canStartPaper ? colors.textSecondary : colors.textMuted)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke(canStartPaper ? colors.border : colors.border.opacity(0.3), lineWidth: 2)
                    )
                    .disabled(!canStartPaper)
                    .opacity(canStartPaper ? 1 : 0.4)

                    // Go Live
                    Button(action: onGoLive) {
                        Text("\(L10n.LiveReadiness.goLive) ▸")
                            .font(PulseFonts.monoLabel)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, PulseSpacing.lg)
                            .padding(.vertical, PulseSpacing.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canStartLiveSmall ? PulseColors.accent : colors.textMuted)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .fill(canStartLiveSmall ? PulseColors.accent.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.xs)
                            .stroke(canStartLiveSmall ? PulseColors.accent.opacity(0.3) : colors.border.opacity(0.3), lineWidth: 2)
                    )
                    .disabled(!canStartLiveSmall)
                    .opacity(canStartLiveSmall ? 1 : 0.4)

                    // Full Live (locked)
                    Text(L10n.LiveReadiness.fullLive)
                        .font(PulseFonts.monoLabel)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(colors.textMuted)
                        .padding(.horizontal, PulseSpacing.lg)
                        .padding(.vertical, PulseSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: PulseRadii.xs)
                                .stroke(colors.border.opacity(0.3), lineWidth: 2)
                        )
                        .opacity(canStartFullLive ? 1 : 0.35)

                    Spacer()
                }
                .padding(PulseSpacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(PulseColors.accent.opacity(0.08), lineWidth: 1)
        )
    }
}
