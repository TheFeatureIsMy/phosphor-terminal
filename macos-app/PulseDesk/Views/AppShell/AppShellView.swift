// AppShellView.swift — 主布局壳
// ProofAlpha 设计：整个控制台是一块连续的玻璃面板
// 侧边栏、工具栏、内容区是同一表面的不同区域，不是独立浮层

import SwiftUI

struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors

    @State private var dashboardVM: DashboardViewModel?
    @State private var strategiesVM: StrategiesViewModel?
    @State private var backtestVM: BacktestViewModel?

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                // 左侧：侧边栏
                sidebarSection

                // 右侧：工具栏 + 内容区
                VStack(spacing: 0) {
                    ConsoleToolbar(systemStatus: dashboardVM?.systemStatus)
                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        // 整个窗口是一块统一的玻璃面板
        // ProofAlpha: bg-[rgba(24,24,27,0.55)] + backdrop-blur + 背景层
        .background {
            ZStack {
                colors.background
                BackgroundLayersView()
                // 全局玻璃材质 — 覆盖整个窗口
                Rectangle().fill(.ultraThinMaterial)
                // ProofAlpha 表面色 — 统一的深色玻璃底
                Rectangle().fill(colors.cardBackground)
            }
            .ignoresSafeArea()
        }
        .overlay {
            if appState.showCommandPalette {
                CommandPaletteView()
            }
        }
        .onAppear {
            if dashboardVM == nil {
                dashboardVM = DashboardViewModel(client: networkClient)
            }
            if strategiesVM == nil {
                strategiesVM = StrategiesViewModel(client: networkClient)
            }
            if backtestVM == nil {
                backtestVM = BacktestViewModel(client: networkClient)
            }
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
        case .dashboard:
            if let vm = dashboardVM {
                DashboardView(viewModel: vm)
            } else {
                ProgressView("加载中...")
            }
        case .strategies:
            if let vm = strategiesVM {
                StrategiesListView(viewModel: vm)
            } else {
                ProgressView("加载中...")
            }
        case .backtest:
            if let vm = backtestVM {
                BacktestView(viewModel: vm)
            } else {
                ProgressView("加载中...")
            }
        case .trades:
            TradesView()
        case .aiStudio:
            AIStudioView()
        case .sentiment:
            SentimentView()
        case .attribution:
            AttributionView()
        case .aiProviders:
            AIProvidersView()
        case .risk:
            RiskView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - 控制台工具栏 — 同一玻璃面板的顶部区域
struct ConsoleToolbar: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var currentTime = Date()
    @State private var showNotifications = false
    @State private var notificationViewModel: NotificationViewModel?

    var systemStatus: SystemStatus?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            // 面包屑 — 终端风格
            HStack(spacing: PulseSpacing.xxs) {
                Text("//")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.accent)
                Text(appState.selectedRoute.label)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(1.5)
            }

            Spacer()

            // 系统指标 — 从 SystemStatus 读取
            HStack(spacing: PulseSpacing.lg) {
                metricBadge(icon: "clock", value: systemStatus?.uptime ?? "—")
                metricBadge(icon: "cpu", value: "\(systemStatus?.activeStrategies ?? 0) 策略")
                metricBadge(icon: "point.3.connected.trianglepath.connected", value: "\(systemStatus?.openPositions ?? 0) 持仓")
            }

            // 分隔点
            Circle()
                .fill(colors.textMuted)
                .frame(width: 2, height: 2)

            // 时钟
            Text(timeFormatter.string(from: currentTime))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .onReceive(timer) { time in currentTime = time }

            // 连接状态
            StatusDot(status: systemStatus?.apiStatus == .connected ? .online : .offline)

            // 搜索
            Button {
                appState.showCommandPalette.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)

            // 通知
            Button {
                showNotifications.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.textMuted)

                    if let vm = notificationViewModel, vm.unreadCount > 0 {
                        Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(PulseColors.danger))
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNotifications) {
                if let vm = notificationViewModel {
                    NotificationPopover(viewModel: vm) {
                        showNotifications = false
                        appState.selectedRoute = .settings
                    }
                }
            }

            // 用户
            Circle()
                .fill(PulseColors.accent.opacity(0.15))
                .frame(width: 22, height: 22)
                .overlay(
                    Text("T")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.accent)
                )
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)
        }
        .onAppear {
            if notificationViewModel == nil {
                notificationViewModel = NotificationViewModel(client: networkClient)
            }
        }
    }

    private func metricBadge(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(value)
                .font(PulseFonts.monoLabel)
        }
        .foregroundStyle(colors.textMuted)
    }
}
