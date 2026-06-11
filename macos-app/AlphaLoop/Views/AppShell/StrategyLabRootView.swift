// StrategyLabRootView.swift — 策略实验室工作区
// 保活 STRATEGY + AI RESEARCH + GROWTH 全部二级页面

import SwiftUI

struct StrategyLabRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient

    @State private var strategiesVM: StrategiesViewModel?
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                content
            }
        }
        .onAppear {
            if strategiesVM == nil {
                strategiesVM = StrategiesViewModel(client: networkClient)
            }
        }
        .onChange(of: appState.primaryWorkspace) { _, newValue in
            if newValue == .strategyLab { isVisible = true }
        }
        .onAppear {
            if appState.primaryWorkspace == .strategyLab { isVisible = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selectedRoute {
        case .strategyWorkspace:
            StrategyWorkspaceConsoleView()
        case .backtestSimulation:
            BacktestLabView()
        case .aiResearchRoom:
            AIStudioView()
        case .agentPlatform:
            AgentPlatformView()
        case .signalCenter:
            SignalCenterView()
        case .marketSentiment:
            SentimentView()
        case .growthReview:
            GrowthView()
        case .failureClustering:
            FailureClusteringView()
        case .strategyOptimization:
            StrategyOptimizationView()
        case .strategyDetail:
            strategyDetailRoute
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var strategyDetailRoute: some View {
        if let v2Id = appState.selectedStrategyV2Id {
            StrategyDetailView(strategyId: v2Id, client: networkClient)
        } else if let id = appState.selectedStrategyId {
            StrategyDetailView(strategyId: "\(id)", client: networkClient)
        } else {
            LoadingView(type: .detail)
        }
    }
}
