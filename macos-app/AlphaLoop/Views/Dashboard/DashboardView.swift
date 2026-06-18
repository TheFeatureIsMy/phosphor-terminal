// DashboardView.swift — Main Dashboard Cockpit
// Production control tower. All cards use real backend data. Empty states
// surface the data-source-unavailable tag (no fabricated values).
// Layout:
//   PageHeader  →  StatusBar (compact infra cells)  →
//   AccountHero (equity + KPIs + mode + sparkline)  →
//   AvailableActionsRow  →  3 cards (Runtime / Readiness / Risk)  →
//   PositionsTable  →  ProviderHealthCard  →  AIModelStatusCard  →
//   SignalsFeedCard (with source traces)  →  DecisionFeed + AlertTimeline  →
//   LearnAlphaLoopCard (when no data)  →  EmergencyActionBar

import SwiftUI

struct DashboardView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
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
        if viewModel.isDataSourceUnavailable && !viewModel.isLoading {
            DataSourceUnavailableView(
                reasonCodes: viewModel.reasonCodes,
                onRetry: { await viewModel.load() }
            )
        } else if viewModel.isLoading && viewModel.account == nil && viewModel.kpis == nil {
            LoadingView(type: .dashboard)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    pageHeader
                        .staggeredAppearance(index: 0)

                    if let sys = viewModel.system {
                        DashboardStatusBar(system: sys, reasonCodes: viewModel.reasonCodes)
                            .staggeredAppearance(index: 1)
                    }

                    AccountHeroCard(
                        account: viewModel.account,
                        kpis: viewModel.kpis,
                        mode: currentMode,
                        dataSourceAvailable: viewModel.bffAvailable || viewModel.kpisAvailable,
                        equityCurve: viewModel.equityCurve
                    )
                    .staggeredAppearance(index: 2)

                    if !viewModel.availableActions.isEmpty {
                        AvailableActionsRow(
                            actions: viewModel.availableActions,
                            onAction: { action in await viewModel.performAction(action) }
                        )
                        .staggeredAppearance(index: 3)
                    }

                    HStack(spacing: 10) {
                        if let runtime = viewModel.runtime {
                            StrategyRuntimeCard(runtime: runtime)
                        }
                        LiveReadinessCard(
                            system: viewModel.system,
                            readiness: viewModel.liveReadiness,
                            dataSourceAvailable: viewModel.liveReadinessAvailable || viewModel.bffAvailable
                        )
                        if let risk = viewModel.risk {
                            GlobalRiskCard(risk: risk)
                        }
                    }
                    .staggeredAppearance(index: 4)

                    PositionRiskTable(
                        positions: viewModel.positions,
                        openCount: viewModel.runtime?.openPositions ?? viewModel.positions.count,
                        dataSourceAvailable: viewModel.positionsAvailable
                    )
                    .staggeredAppearance(index: 5)

                    HStack(alignment: .top, spacing: 10) {
                        ProviderHealthCard(
                            summary: viewModel.providerHealth,
                            dataSourceAvailable: viewModel.providerHealthAvailable
                        )
                        AIModelStatusCard(
                            models: viewModel.aiModels,
                            dataSourceAvailable: viewModel.aiModelsAvailable
                        )
                    }
                    .staggeredAppearance(index: 6)

                    SignalsFeedCard(
                        signals: viewModel.recentSignals,
                        dataSourceAvailable: viewModel.signalsAvailable
                    )
                    .staggeredAppearance(index: 7)

                    HStack(alignment: .top, spacing: 10) {
                        RecentDecisionFeed(decisions: viewModel.recentDecisions)
                        AlertTimeline(alerts: viewModel.alerts)
                    }
                    .staggeredAppearance(index: 8)

                    if viewModel.state == "unknown" && viewModel.positions.isEmpty && viewModel.recentSignals.isEmpty {
                        LearnAlphaLoopCard()
                            .staggeredAppearance(index: 9)
                    }

                    EmergencyActionBar(viewModel: viewModel)
                        .staggeredAppearance(index: 10)

                    Spacer().frame(height: PulseSpacing.lg)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .safeAreaPadding(.top, PulseSpacing.xxs)
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: PulseSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xs) {
                    Text("//")
                        .font(PulseFonts.monoLabel)
                        .foregroundStyle(PulseColors.accent)
                    Text(L10n.Dashboard.pageHeader)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(colors.textPrimary)
                        .tracking(0.5)
                    ModePill(mode: currentMode, compact: true)
                }
                Text(L10n.Dashboard.pageSubtitle)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
            Spacer()
            if viewModel.isDataSourceUnavailable {
                badge(
                    text: L10n.Dashboard.dataSourceUnavailable,
                    color: PulseColors.warning
                )
            } else if viewModel.bffAvailable || viewModel.kpisAvailable {
                badge(text: L10n.Dashboard.dataSourceBadge, color: PulseColors.accent)
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.10))
            )
            .overlay(
                Capsule().stroke(color.opacity(0.30), lineWidth: 0.7)
            )
    }

    private var currentMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel.system?.liveReadinessState,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }
}
