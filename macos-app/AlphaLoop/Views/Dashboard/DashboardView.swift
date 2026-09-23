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

                    // 重构：顶部 KPI 指令条（权益/盈亏/回撤/就绪度/风险）
                    kpiStrip
                        .staggeredAppearance(index: 2)

                    // Bento row 1: equity(5) + 曲线(7)
                    HStack(alignment: .top, spacing: 18) {
                        ProtocolEquityCard(
                            account: viewModel.account,
                            kpis: viewModel.kpis,
                            runtime: viewModel.runtime,
                            available: viewModel.bffAvailable || viewModel.kpisAvailable
                        )
                        .frame(width: 400)
                        .frame(maxHeight: .infinity)

                        ProtocolEquityCurveCard(
                            points: viewModel.equityCurve,
                            available: viewModel.equityCurveAvailable
                        )
                        .frame(maxHeight: .infinity)
                    }
                    .staggeredAppearance(index: 2)

                    // Bento row 2: 运行时 / 就绪度 / 风险
                    HStack(alignment: .top, spacing: 18) {
                        ProtocolRuntimeCard(
                            runtime: viewModel.runtime,
                            kpis: viewModel.kpis,
                            online: viewModel.bffAvailable
                        )
                        .frame(maxHeight: .infinity)
                        ProtocolReadinessCard(
                            readiness: viewModel.liveReadiness,
                            available: viewModel.liveReadinessAvailable || viewModel.bffAvailable
                        )
                        .frame(maxHeight: .infinity)
                        ProtocolRiskCard(
                            risk: viewModel.risk,
                            account: viewModel.account
                        )
                        .frame(maxHeight: .infinity)
                    }
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
                        .frame(maxHeight: .infinity)
                        ProtocolAlertFeed(alerts: viewModel.alerts)
                        .frame(maxHeight: .infinity)
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
            .scrollEdgeEffectStyle(.soft, for: .vertical)
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
                    badge(text: L10n.Dashboard.dataSourceBadge, color: PulseColors.accentText)
                }
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(PulseFonts.mono(10, .semibold))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .fill(color.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadii.badge)
                    .stroke(color.opacity(0.30), lineWidth: 0.7)
            )
    }

    private var currentMode: ModePill.Mode {
        ModePill.Mode.resolve(
            liveReadinessState: viewModel.system?.liveReadinessState,
            isLiveMode: appState.isLiveMode,
            isMockMode: !appState.isLiveMode && !appState.isDetectingBackend
        )
    }

    // MARK: - KPI 指令条（重构：顶部紧凑指标带）
    private var kpiStrip: some View {
        let acc = viewModel.account
        let kpis = viewModel.kpis
        let readiness = viewModel.liveReadiness
        let risk = viewModel.risk
        let todayPct = acc?.todayPnlPct ?? kpis?.pnlChangePct ?? 0
        let dd = acc?.maxDrawdownPct ?? 0
        let score = readiness?.score
        let riskState = risk?.globalState.uppercased() ?? "—"
        return HStack(spacing: 0) {
            kpiTile(label: L10n.Dashboard.equity,
                    value: (acc?.equity).map { String(format: "%.2f", $0) } ?? "—",
                    unit: acc?.currency ?? "USDT", color: colors.textPrimary)
            kpiDivider()
            kpiTile(label: L10n.zh("今日盈亏", en: "Today P&L"),
                    value: String(format: "%+.2f%%", todayPct),
                    color: todayPct >= 0 ? PulseColors.bullish : PulseColors.bearish)
            kpiDivider()
            kpiTile(label: L10n.zh("最大回撤", en: "Max DD"),
                    value: String(format: "%.2f%%", dd), color: PulseColors.bearish)
            kpiDivider()
            kpiTile(label: L10n.zh("就绪度", en: "Readiness"),
                    value: (score).map { "\($0)/100" } ?? "—", color: PulseColors.accentText)
            kpiDivider()
            kpiTile(label: L10n.zh("风险状态", en: "Risk"),
                    value: riskState,
                    color: riskState == "NORMAL" ? PulseColors.bullish : PulseColors.warning)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        
        .voltCardSurface()
    }

    private func kpiTile(label: String, value: String, unit: String? = nil, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PulseFonts.mono(9.5, .semibold))
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(PulseFonts.mono(18, .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let unit {
                    Text(unit).font(PulseFonts.mono(10, .medium)).foregroundStyle(colors.textMuted)
                }
            }
        }
        .padding(.horizontal, PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kpiDivider() -> some View {
        Rectangle().fill(colors.border).frame(width: 1, height: 30)
    }
}
