// AppShellView.swift — 主布局壳
// AlphaLoop 设计：整个控制台是一块连续的玻璃面板
// 侧边栏、工具栏、内容区是同一表面的不同区域，不是独立浮层

import SwiftUI

struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(ToastManager.self) private var toastManager
    @Environment(ErrorHandler.self) private var errorHandler

    @State private var dashboardVM: DashboardViewModel?
    @State private var liveReadinessVM: LiveReadinessViewModel?
    @State private var strategiesVM: StrategiesViewModel?
    @State private var previousWorkspaceIndex: Int = 0

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                // 左侧：侧边栏
                sidebarSection

                // 右侧：工具栏 + 内容区
                VStack(spacing: 0) {
                    GlobalStatusBar()
                    ZStack {
                        detailContent
                            .id(appState.selectedRoute)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.92)),
                                removal: .scale(scale: 0.92).combined(with: .opacity)
                            ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(PulseAnimation.workspaceTransition, value: appState.selectedRoute)
                }
            }
        }
        // 整个窗口是一块统一的玻璃面板
        // AlphaLoop: bg-[rgba(24,24,27,0.55)] + backdrop-blur + 背景层
        .background {
            ZStack {
                colors.background
                BackgroundLayersView()
                // 全局玻璃材质 — 覆盖整个窗口
                Rectangle().fill(.ultraThinMaterial)
                // AlphaLoop 表面色 — 统一的深色玻璃底
                Rectangle().fill(colors.cardBackground)
            }
            .ignoresSafeArea()
        }
        .overlay {
            if appState.showCommandPalette {
                CommandPaletteView()
            }
        }
        .overlay {
            ToastOverlayView(toastManager: toastManager)
        }
        .onAppear {
            if dashboardVM == nil {
                dashboardVM = DashboardViewModel(client: networkClient)
            if liveReadinessVM == nil {
                liveReadinessVM = LiveReadinessViewModel(client: networkClient)
            }
            }
            dashboardVM?.errorHandler = errorHandler
            if strategiesVM == nil {
                strategiesVM = StrategiesViewModel(client: networkClient)
            }
            strategiesVM?.errorHandler = errorHandler
        }
    }

    // MARK: - 侧边栏区域 — 同一表面的子区域
    private var sidebarSection: some View {
        SidebarView()
    }

    // MARK: - 内容路由
    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedRoute {
        // OVERVIEW
        case .dashboard:
            if let vm = dashboardVM {
                DashboardView(viewModel: vm)
            } else {
                LoadingView(type: .detail)
            }
        case .liveReadiness:
            if let vm = liveReadinessVM { LiveReadinessView(viewModel: vm) } else { LoadingView(type: .detail) }
        // STRATEGY
        case .strategyWorkspace:
            StrategyWorkspaceConsoleView()
        case .backtestSimulation:
            BacktestLabView()
        // STRUCTURE
        case .marketStructure:
            MarketStructureView()
        case .structureMatrix:
            StructureMatrixView()
        case .manipulationRadar:
            ManipulationRadarView()
        // EXECUTION
        case .executionCenter:
            ExecutionCenterView()
        case .ordersPositions:
            OrdersPositionsView()
        case .reconciliationBus:
            ReconciliationBusView()
        // RISK
        case .riskCenter:
            RiskCenterView()
        case .stopProtection:
            StopProtectionView()
        case .circuitBreakers:
            CircuitBreakersView()
        // AI RESEARCH
        case .aiResearchRoom:
            AIStudioView()
        case .agentPlatform:
            AgentPlatformView()
        case .signalCenter:
            SignalCenterView()
        case .marketSentiment:
            SentimentView()
        // GROWTH
        case .growthReview:
            GrowthView()
        case .failureClustering:
            FailureClusteringView()
        case .strategyOptimization:
            StrategyOptimizationView()
        // SYSTEM
        case .serviceManagement:
            AIProvidersView()
        case .dataSourceManagement:
            DataSourcesView()
        case .systemSettings:
            SettingsView()
        // Internal
        case .strategyDetail:
            if let v2Id = appState.selectedStrategyV2Id {
                StrategyDetailView(strategyId: v2Id, client: networkClient)
            } else if let id = appState.selectedStrategyId {
                StrategyDetailView(strategyId: "\(id)", client: networkClient)
            } else {
                LoadingView(type: .detail)
            }
        }
    }

    // MARK: - Placeholder View (coming soon)
    @ViewBuilder
    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: PulseSpacing.lg) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(PulseColors.accent.opacity(0.4))
                .shadow(color: PulseColors.accent.opacity(0.2), radius: 12)
            Text(title)
                .font(PulseFonts.displaySubheading)
                .foregroundStyle(colors.textPrimary)
            Text("Coming soon")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(PulseAnimation.easeOutMedium, value: appState.selectedRoute)
    }
}

