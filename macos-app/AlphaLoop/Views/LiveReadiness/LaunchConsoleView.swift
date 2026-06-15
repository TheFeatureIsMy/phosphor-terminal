// LaunchConsoleView.swift — Launch authorization (editorial verdict style)

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
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            // Blockers
            if blockingReasons.isEmpty {
                HStack(spacing: PulseSpacing.xs) {
                    Circle()
                        .fill(PulseColors.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: PulseColors.accent.opacity(0.5), radius: 3)
                    Text(L10n.LiveReadiness.allClear)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(PulseColors.accent)
                }
            } else {
                VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                    ForEach(Array(blockingReasons.enumerated()), id: \.offset) { i, reason in
                        HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.xs) {
                            Text("\(toRoman(i + 1)).")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PulseColors.danger.opacity(0.7))
                                .frame(width: 24, alignment: .leading)

                            Text(reason["code"] ?? "")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PulseColors.danger)

                            if let msg = reason["message"], !msg.isEmpty {
                                Text("\u{2014} \u{201C}\(msg)\u{201D}")
                                    .font(.system(size: 12.5, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle()
                .fill(colors.border)
                .frame(height: 1)

            // Action buttons
            HStack(spacing: PulseSpacing.md) {
                Spacer()

                // Paper Trade (ghost)
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
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(colors.border.opacity(canStartPaper ? 0.5 : 0.2), lineWidth: 1)
                )
                .disabled(!canStartPaper)
                .opacity(canStartPaper ? 1 : 0.4)

                // Go Live (primary CTA, verdict-style)
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
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .fill(canStartLiveSmall ? PulseColors.accent.opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.sm)
                        .stroke(
                            canStartLiveSmall ? PulseColors.accent.opacity(0.45) : colors.border.opacity(0.2),
                            lineWidth: 1
                        )
                )
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
                        RoundedRectangle(cornerRadius: PulseRadii.sm)
                            .stroke(colors.border.opacity(0.15), lineWidth: 1)
                    )
                    .opacity(canStartFullLive ? 0.8 : 0.25)

                Spacer()
            }
        }
    }

    private func toRoman(_ n: Int) -> String {
        switch n {
        case 1: "i"
        case 2: "ii"
        case 3: "iii"
        case 4: "iv"
        case 5: "v"
        default: "\(n)"
        }
    }
}
