// TradingConsoleRootView.swift — 交易控制台工作区
// 保活 OVERVIEW + STRUCTURE + EXECUTION + RISK 全部二级页面

import SwiftUI

struct TradingConsoleRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @Environment(ErrorHandler.self) private var errorHandler

    @State private var dashboardVM: DashboardViewModel?
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                content
            }
        }
        .onAppear {
            if dashboardVM == nil {
                dashboardVM = DashboardViewModel(client: networkClient)
            }
            dashboardVM?.errorHandler = errorHandler
        }
        .onChange(of: appState.primaryWorkspace) { _, newValue in
            if newValue == .tradingConsole { isVisible = true }
        }
        .onAppear {
            if appState.primaryWorkspace == .tradingConsole { isVisible = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selectedRoute {
        case .dashboard:
            if let vm = dashboardVM {
                DashboardView(viewModel: vm)
            } else {
                LoadingView(type: .detail)
            }
        case .liveReadiness:
            LiveReadinessView(viewModel: LiveReadinessViewModel(client: networkClient))
        case .marketStructure:
            MarketStructureView()
        case .structureMatrix:
            StructureMatrixView()
        case .manipulationRadar:
            ManipulationRadarView()
        case .executionCenter:
            ExecutionCenterView()
        case .ordersPositions:
            OrdersPositionsView()
        case .reconciliationBus:
            ReconciliationBusView()
        case .riskCenter:
            RiskCenterView()
        case .stopProtection:
            StopProtectionView()
        case .circuitBreakers:
            CircuitBreakersView()
        default:
            EmptyView()
        }
    }
}
