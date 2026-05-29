// AppState.swift — 全局应用状态
// 替代 Zustand app-store.ts

import SwiftUI

@Observable
final class AppState {
    /// 是否已完成启动页
    var hasLaunched: Bool = false

    /// 当前选中的侧边栏路由
    var selectedRoute: AppRoute = .dashboard

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
