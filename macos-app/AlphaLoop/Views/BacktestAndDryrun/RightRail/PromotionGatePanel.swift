// PromotionGatePanel.swift — Live-trading readiness gate (judgment + navigation only).
// Uses PerStrategyReadiness.grandStatus and gates for display; CTA navigates to .liveReadiness.

import SwiftUI

struct PromotionGatePanel: View {
    @Environment(BacktestLabViewModel.self) private var vm
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(L10n.BacktestLab.Context.promotion).font(PulseFonts.caption.weight(.semibold))
            if let readiness = vm.readiness {
                HStack {
                    Circle()
                        .fill(readiness.grandStatus == "ready_for_live" ? PulseColors.success : PulseColors.amber)
                        .frame(width: 8, height: 8)
                    Text(readiness.grandStatus == "ready_for_live"
                         ? L10n.BacktestLab.Context.ready
                         : L10n.BacktestLab.Context.notReady)
                        .font(PulseFonts.micro.weight(.semibold))
                }
                // Show strategy gates (primary) + system gates
                let allGates = readiness.strategyGates + readiness.systemGates
                ForEach(allGates, id: \.key) { gate in
                    HStack {
                        Image(systemName: gate.status == "healthy" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(gate.status == "healthy" ? PulseColors.success : PulseColors.danger)
                            .font(.caption)
                        Text(gate.key).font(PulseFonts.micro).foregroundStyle(colors.textSecondary)
                    }
                }
                let isReady = readiness.grandStatus == "ready_for_live"
                Button {
                    appState.selectedRoute = .liveReadiness
                } label: {
                    Text(L10n.BacktestLab.Context.goLive)
                        .font(PulseFonts.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isReady ? PulseColors.accent : colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.sm))
                }
                .buttonStyle(.plain)
                .disabled(!isReady)
            } else {
                Text(L10n.BacktestLab.Context.noReadiness)
                    .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
        .padding(PulseSpacing.md)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.card))
    }
}
