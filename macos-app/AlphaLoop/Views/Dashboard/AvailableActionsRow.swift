// AvailableActionsRow.swift — Suggested actions ghost-button row
// HStack of up to 3 action buttons, styled by action type

import SwiftUI

struct AvailableActionsRow: View {
    @Environment(PulseColors.self) private var colors
    let actions: [AvailableActionResponse]

    var body: some View {
        if !actions.isEmpty {
            HStack(spacing: PulseSpacing.xs) {
                Text(L10n.Dashboard.suggestedActions)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                ForEach(Array(actions.prefix(3).enumerated()), id: \.element.type) { index, action in
                    actionButton(action)
                        .staggeredAppearance(index: index)
                }

                Spacer()
            }
            .padding(.horizontal, PulseSpacing.xxs)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(_ action: AvailableActionResponse) -> some View {
        let style = buttonStyle(for: action.type)

        Button {
            // Action handling delegated to parent via environment or callback
        } label: {
            HStack(spacing: 6) {
                if action.confirmRequired {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 8, weight: .semibold))
                }
                Text(action.label)
                    .font(PulseFonts.micro)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(style.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(style.color.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .stroke(style.color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!action.enabled)
        .opacity(action.enabled ? 1.0 : 0.5)
    }

    // MARK: - Button Style

    private struct ActionButtonStyle {
        let color: Color
    }

    private func buttonStyle(for type: String) -> ActionButtonStyle {
        let lower = type.lowercased()
        if lower.contains("deploy") || lower.contains("approve") || lower.contains("start") {
            return ActionButtonStyle(color: PulseColors.accent)
        } else if lower.contains("review") || lower.contains("inspect") || lower.contains("check") {
            return ActionButtonStyle(color: PulseColors.cyan)
        } else if lower.contains("tighten") || lower.contains("reduce") || lower.contains("stop") || lower.contains("emergency") {
            return ActionButtonStyle(color: PulseColors.warning)
        }
        return ActionButtonStyle(color: colors.textSecondary)
    }
}
