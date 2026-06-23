import SwiftUI

struct PromotionPanel: View {
    @Bindable var viewModel: BacktestLabViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        SectionCard(title: L10n.BacktestLab.sectionPromotion) {
            if let r = viewModel.readiness {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    HStack {
                        Text(L10n.BacktestLab.promotionGrandStatus).font(PulseFonts.caption).foregroundStyle(.secondary)
                        Text(r.grandStatus).font(PulseFonts.body.weight(.semibold))
                    }
                    Divider()
                    let allGates = r.strategyGates + r.systemGates
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        ForEach(allGates) { g in
                            HStack {
                                Circle().fill(g.status == "healthy" ? PulseColors.success
                                              : (g.status == "failed" ? PulseColors.danger : .gray))
                                    .frame(width: 8, height: 8)
                                Text(g.key)
                                Spacer()
                                if g.key.lowercased().contains("backtest") || g.key.lowercased().contains("dry") {
                                    Text(g.status).font(PulseFonts.caption.weight(.semibold))
                                } else {
                                    Text(g.status).font(PulseFonts.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button {
                        appState.selectedRoute = .liveReadiness
                    } label: {
                        Text(r.grandStatus == "ready_for_live"
                             ? L10n.BacktestLab.ctaGoLiveSmall
                             : L10n.BacktestLab.ctaViewReadiness)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(L10n.BacktestLab.promotionUnavailable).foregroundStyle(.secondary)
                Button(L10n.BacktestLab.retry) { Task { await viewModel.loadWorkspaceSnapshot() } }
            }
        }
    }
}
