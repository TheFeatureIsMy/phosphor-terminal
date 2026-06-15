// DashboardView.swift — Main Dashboard Bento Grid
// Top-level view composing all dashboard cards into a responsive bento layout.

import SwiftUI

struct DashboardView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    var viewModel: DashboardViewModel

    var body: some View {
        content
            .id(settingsState.language)
            .task {
                await viewModel.load()
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.account == nil {
            LoadingView(type: .dashboard)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    // Row 0: Status Bar
                    if let sys = viewModel.system {
                        DashboardStatusBar(system: sys, reasonCodes: viewModel.reasonCodes)
                            .staggeredAppearance(index: 0)
                    }

                    // Row 1: Account Hero
                    if let account = viewModel.account {
                        AccountHeroCard(account: account, equityCurve: viewModel.equityCurve)
                            .staggeredAppearance(index: 1)
                    }

                    // Row 1.5: Available Actions
                    if !viewModel.availableActions.isEmpty {
                        AvailableActionsRow(actions: viewModel.availableActions)
                            .staggeredAppearance(index: 2)
                    }

                    // Row 2: Runtime + Readiness + Risk (3 columns)
                    HStack(spacing: 10) {
                        if let runtime = viewModel.runtime {
                            StrategyRuntimeCard(runtime: runtime)
                        }
                        if let sys = viewModel.system {
                            LiveReadinessCard(system: sys)
                        }
                        if let risk = viewModel.risk {
                            GlobalRiskCard(risk: risk)
                        }
                    }
                    .staggeredAppearance(index: 3)

                    // Row 3: Position Risk Table
                    PositionRiskTable(
                        positions: PositionRiskTable.mockPositions,
                        openCount: viewModel.runtime?.openPositions ?? 0
                    )
                    .staggeredAppearance(index: 4)

                    // Row 4: Decisions + Alerts (2 columns)
                    HStack(alignment: .top, spacing: 10) {
                        RecentDecisionFeed(decisions: viewModel.recentDecisions)
                        AlertTimeline(alerts: viewModel.alerts)
                    }
                    .staggeredAppearance(index: 5)

                    // Onboarding card (show when no real data)
                    if viewModel.state == "unknown" {
                        LearnAlphaLoopCard()
                            .staggeredAppearance(index: 6)
                    }

                    // Row 5: Emergency bar (in flow, not fixed)
                    EmergencyActionBar(viewModel: viewModel)
                        .staggeredAppearance(index: 7)

                    // Bottom padding
                    Spacer().frame(height: PulseSpacing.lg)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .safeAreaPadding(.top, PulseSpacing.xxs)
        }
    }
}
