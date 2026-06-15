import SwiftUI

struct EmergencyActionBar: View {
    @Environment(PulseColors.self) private var colors
    var viewModel: DashboardViewModel
    
    @State private var showConfirmHalt = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            // Icon
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 14))
                .foregroundStyle(PulseColors.danger.opacity(0.7))

            // Label
            Text(L10n.Dashboard.emergencyControl)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

            // Halt button
            Button {
                showConfirmHalt = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 10))
                    Text(L10n.Dashboard.haltAllTrading)
                        .font(PulseFonts.monoLabel)
                        .textCase(.uppercase)
                }
                .foregroundStyle(PulseColors.danger)
                .padding(.horizontal, PulseSpacing.sm)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .fill(PulseColors.danger.opacity(isHovered ? 0.12 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadii.button)
                        .stroke(PulseColors.danger.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(PulseAnimation.easeOutFast) { isHovered = h }
            }

            Spacer()

            // Description
            Text(L10n.Dashboard.haltDescription)
                .font(PulseFonts.micro)
                .foregroundStyle(colors.textMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .fill(PulseColors.danger.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(PulseColors.danger.opacity(0.08), lineWidth: 1)
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
