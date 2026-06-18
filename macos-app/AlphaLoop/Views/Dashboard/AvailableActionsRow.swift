// AvailableActionsRow.swift — Action buttons wired to viewModel.performAction
// No empty handlers. All actions route through the ViewModel dispatch.

import SwiftUI

struct AvailableActionsRow: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState

    let actions: [AvailableActionResponse]
    let onAction: (AvailableActionResponse) async -> Void

    @State private var pendingType: String?

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
            .id(settingsState.language)
        }
    }

    @ViewBuilder
    private func actionButton(_ action: AvailableActionResponse) -> some View {
        let style = buttonStyle(for: action.type)
        let isPending = pendingType == action.type

        Button {
            pendingType = action.type
            Task {
                await onAction(action)
                pendingType = nil
            }
        } label: {
            HStack(spacing: 6) {
                if isPending {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else if action.confirmRequired {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 8, weight: .semibold))
                }
                Text(localizedLabel(for: action))
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
        .disabled(!action.enabled || isPending)
        .opacity(action.enabled ? 1.0 : 0.5)
    }

    // MARK: - Helpers

    private func localizedLabel(for action: AvailableActionResponse) -> String {
        switch action.type {
        case "emergency_stop": return L10n.Dashboard.actionEmergencyStop
        case "start_paper": return L10n.Dashboard.actionStartPaper
        case "start_live_small": return L10n.Dashboard.actionStartLiveSmall
        case "start_full_live": return L10n.Dashboard.actionStartFullLive
        case "cancel_all_orders": return L10n.Dashboard.actionCancelAll
        case "force_close_all": return L10n.Dashboard.actionForceClose
        case "run_readiness_check": return L10n.Dashboard.actionRunCheck
        default: return action.label
        }
    }

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
