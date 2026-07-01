// ManipulationRadarView.swift — 操纵雷达主视图（九段叙事流重构版）
// 1280 居中，Masthead + §0–§8，对齐 MarketStructureView / StructureMatrixView 风格家族

import SwiftUI

struct ManipulationRadarView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: ManipulationViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                if vm.isLoading && vm.radarOverview == nil {
                    LoadingView(type: .dashboard).padding(PulseSpacing.lg)
                } else if let overview = vm.radarOverview {
                    radarContent(vm: vm, overview: overview)
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.zh("加载失败", en: "Load Failed"),
                        description: error,
                        primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.loadRadar() } })
                    ).padding(PulseSpacing.lg)
                } else {
                    EmptyStateView(icon: "shield.checkered", title: L10n.Manipulation.noCases, description: L10n.Manipulation.radarSubtitle)
                        .padding(PulseSpacing.lg)
                }
            } else {
                LoadingView(type: .dashboard).padding(PulseSpacing.lg)
            }
        }
        .task { await initialLoad() }
        .onAppear {
            if viewModel == nil { viewModel = ManipulationViewModel(client: networkClient) }
            // CRITICAL: connectStream BEFORE startLiveUpdates to avoid WS event drop race
            viewModel?.connectStream(baseURL: networkClient.baseURL.host != nil ? networkClient.baseURL : nil)
            viewModel?.startLiveUpdates()
        }
        .onDisappear { viewModel?.stopLiveUpdates() }
    }

    private func initialLoad() async {
        if viewModel == nil { viewModel = ManipulationViewModel(client: networkClient) }
        await viewModel?.loadRadar()
    }

    @ViewBuilder
    private func radarContent(vm: ManipulationViewModel, overview: ManipulationRadarOverview) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.xl) {
                MastheadBlock()
                    .staggeredAppearance(index: 0)
                if !overview.activeCases.isEmpty {
                    ActiveCasesStrip(overview: overview, focusedCaseId: vm.focusedCaseId) { id in
                        Task { await vm.focusCase(id) }
                    }
                    .staggeredAppearance(index: 1)
                }
                if let detail = vm.focusedDetail {
                    VerdictPanel(detail: detail)
                        .staggeredAppearance(index: 2)
                    LifecycleTimeline(detail: detail)
                        .staggeredAppearance(index: 3)
                    EvidenceLayerMatrix(detail: detail)
                        .staggeredAppearance(index: 4)
                    WhaleConcentrationPanel(detail: detail)
                        .staggeredAppearance(index: 5)
                    CrossMarketPressurePanel(detail: detail)
                        .staggeredAppearance(index: 6)
                    SocialAccelerationPanel(detail: detail)
                        .staggeredAppearance(index: 7)
                    DualProfileSignalPanel(detail: detail, impact: vm.strategyImpact) { route in
                        appState.selectedRoute = route
                    }
                    .staggeredAppearance(index: 8)
                } else if vm.focusedCaseId != nil {
                    LoadingView(type: .detail)
                }
                ManipulationAlertFeed(alerts: vm.alerts)
                    .staggeredAppearance(index: 9)
                if let similar = vm.similar, !similar.similar.isEmpty {
                    SimilarCasesPanel(similar: similar)
                        .staggeredAppearance(index: 9)
                }
            }
            .padding(.horizontal, PulseSpacing.xl)
            .padding(.vertical, PulseSpacing.lg)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(colors.background)
        .id(settingsState.language)
    }
}

private struct MastheadBlock: View {
    @Environment(PulseColors.self) private var colors
    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.sm) {
                Text("ALPHALOOP").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Text("·").foregroundStyle(colors.textMuted)
                Text(L10n.zh("操纵雷达", en: "MANIPULATION RADAR")).font(PulseFonts.displaySubheading)
                Text("·").foregroundStyle(colors.textMuted)
                Text(L10n.zh("统计推断", en: "STATISTICAL INFERENCE")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
            Text(L10n.Manipulation.disclaimer)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseSpacing.lg)
        .glassEffect()
    }
}
