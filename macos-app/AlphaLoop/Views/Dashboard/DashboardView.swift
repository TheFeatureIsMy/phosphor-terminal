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
                VStack(spacing: 18) {
                    pageHeader
                        .staggeredAppearance(index: 0)

                    if !viewModel.availableActions.isEmpty {
                        AvailableActionsRow(
                            actions: viewModel.availableActions,
                            onAction: { action in await viewModel.performAction(action) }
                        )
                        .staggeredAppearance(index: 1)
                    }

                    // Bento row 1: equity(5) + 曲线(7)
                    HStack(alignment: .top, spacing: 18) {
                        ProtocolEquityCard(
                            account: viewModel.account,
                            kpis: viewModel.kpis,
                            runtime: viewModel.runtime,
                            available: viewModel.bffAvailable || viewModel.kpisAvailable
                        )
                        .frame(width: 400)

                        ProtocolEquityCurveCard(
                            points: viewModel.equityCurve,
                            available: viewModel.equityCurveAvailable
                        )
                    }
                    .staggeredAppearance(index: 2)

                    // Bento row 2: 运行时 / 就绪度 / 风险
                    HStack(alignment: .top, spacing: 18) {
                        ProtocolRuntimeCard(
                            runtime: viewModel.runtime,
                            kpis: viewModel.kpis,
                            online: viewModel.bffAvailable
                        )
                        ProtocolReadinessCard(
                            readiness: viewModel.liveReadiness,
                            available: viewModel.liveReadinessAvailable || viewModel.bffAvailable
                        )
                        ProtocolRiskCard(
                            risk: viewModel.risk,
                            account: viewModel.account
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .staggeredAppearance(index: 3)

                    // 持仓
                    PositionRiskTable(
                        positions: viewModel.positions,
                        openCount: viewModel.runtime?.openPositions ?? viewModel.positions.count,
                        dataSourceAvailable: viewModel.positionsAvailable
                    )
                    .staggeredAppearance(index: 4)

                    // Bento row 3: AI 决策流 + 风险告警
                    HStack(alignment: .top, spacing: 18) {
                        ProtocolDecisionFeed(
                            decisions: viewModel.recentDecisions,
                            signals: viewModel.recentSignals
                        )
                        ProtocolAlertFeed(alerts: viewModel.alerts)
                    }
                    .staggeredAppearance(index: 5)

                    if viewModel.state == "unknown" && viewModel.positions.isEmpty && viewModel.recentSignals.isEmpty {
                        LearnAlphaLoopCard()
                            .staggeredAppearance(index: 6)
                    }

                    Spacer().frame(height: PulseSpacing.lg)
                }
                .padding(.horizontal, 28)
                .padding(.top, PulseSpacing.md)
                .frame(maxWidth: PulseSpacing.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .safeAreaPadding(.top, PulseSpacing.xxs)
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        QuantPageHeader(
            eyebrow: "OVERVIEW",
            title: L10n.Dashboard.pageHeader,
            subtitle: L10n.Dashboard.pageSubtitle
        ) {
            HStack(spacing: PulseSpacing.xs) {
                ModePill(mode: currentMode, compact: true)
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
