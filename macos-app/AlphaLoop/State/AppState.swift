// AppState.swift — 全局应用状态
// 替代 Zustand app-store.ts

import SwiftUI

// MARK: - 一级工作区

enum PrimaryWorkspace: String, CaseIterable, Identifiable {
    case tradingConsole
    case strategyLab
    case operations

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tradingConsole: return "Trading Console"
        case .strategyLab: return "Strategy Lab"
        case .operations: return "Operations"
        }
    }

    var icon: String {
        switch self {
        case .tradingConsole: return "cube.transparent"
        case .strategyLab: return "flask"
        case .operations: return "gearshape.2"
        }
    }

    /// 短标签（用于侧边栏紧凑模式）
    var shortLabel: String {
        switch self {
        case .tradingConsole: return "Trading"
        case .strategyLab: return "Lab"
        case .operations: return "Ops"
        }
    }
}

// MARK: - AppState

@Observable
final class AppState {
    /// 是否已完成启动页
    var hasLaunched: Bool = false

    /// 当前选中的侧边栏路由
    var selectedRoute: AppRoute = .dashboard {
        didSet {
            guard oldValue != selectedRoute else { return }
            recentRoutes.removeAll { $0 == selectedRoute }
            recentRoutes.insert(selectedRoute, at: 0)
            if recentRoutes.count > 10 {
                recentRoutes = Array(recentRoutes.prefix(10))
            }
        }
    }

    /// 当前一级工作区
    var primaryWorkspace: PrimaryWorkspace {
        selectedRoute.primaryWorkspace
    }

    /// 侧边栏是否折叠
    var sidebarCollapsed: Bool = false

    /// 侧边栏是否固定
    var sidebarPinned: Bool = true

    /// 命令面板是否显示
    var showCommandPalette: Bool = false

    /// 通知数量 (由 NotificationViewModel 驱动，保留用于兼容)
    var unreadNotifications: Int = 0

    /// 系统状态
    var systemStatus: SystemStatus?

    /// 网络模式标记
    var isLiveMode: Bool = false

    /// 后端连接检测中
    var isDetectingBackend: Bool = true

    /// 后端不可达（显示错误页）
    var backendUnavailable: Bool = false

    /// 重试后端检测的触发器（递增触发 .task(id:) 重新执行）
    var retryBackendTrigger: Int = 0

    /// MRU 最近访问路由 (max 10)
    var recentRoutes: [AppRoute] = []

    /// 当前选中的策略 ID（用于详情页路由）
    var selectedStrategyId: Int?

    /// v2.5 策略 ID (UUID string)
    var selectedStrategyV2Id: String?

    /// 切换侧边栏折叠
    func toggleSidebar() {
        withAnimation(PulseAnimation.springDefault) {
            sidebarCollapsed.toggle()
        }
    }

    /// 切换侧边栏固定
    func toggleSidebarPinned() {
        sidebarPinned.toggle()
    }
}
