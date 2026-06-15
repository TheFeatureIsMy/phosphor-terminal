// EmergencyActionBar.swift — Fixed emergency halt bar for Dashboard
// Sits at the bottom of the Dashboard ZStack, providing one-click emergency stop.

import SwiftUI

struct EmergencyActionBar: View {
    @Environment(PulseColors.self) private var colors

    var viewModel: DashboardViewModel

    @State private var showConfirmHalt = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(PulseColors.danger.opacity(0.15))
                .frame(height: 1)

            // Content
            HStack(spacing: PulseSpacing.lg) {
                // Label
                Text(L10n.Dashboard.emergencyControl)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(1.0)

                // Halt button
                Button {
                    showConfirmHalt = true
                } label: {
                    HStack(spacing: PulseSpacing.xxs) {
                        Text("⚠")
                        Text(L10n.Dashboard.haltAllTrading)
                            .font(PulseFonts.monoLabel)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(PulseColors.danger)
                    .padding(.horizontal, PulseSpacing.md)
                    .padding(.vertical, PulseSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PulseRadii.button)
                            .fill(PulseColors.danger.opacity(isHovered ? 0.15 : 0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseRadii.button)
                            .stroke(PulseColors.danger.opacity(0.30), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(PulseAnimation.easeOutFast) { isHovered = hovering }
                }

                // Description
                Text(L10n.Dashboard.haltDescription)
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
            .padding(.horizontal, PulseSpacing.lg)
            .padding(.vertical, PulseSpacing.sm)
        }
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(colors.cardBackground.opacity(0.94))
            }
        )
        .confirmDialog(
            isPresented: $showConfirmHalt,
            title: L10n.Dashboard.confirmHaltTitle,
            message: L10n.Dashboard.confirmHaltMessage,
            confirmLabel: L10n.Dashboard.haltAllTrading,
            confirmStyle: .danger,
            onConfirm: {
                showConfirmHalt = false
                Task { await viewModel.emergencyStop() }
            }
        )
    }
}
