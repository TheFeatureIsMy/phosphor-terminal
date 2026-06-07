// WorkspaceTabBar.swift — 工作区二级导航 Tab 栏
// Phase 2: 替代侧边栏分组，提供当前工作区内的子页面切换

import SwiftUI

struct WorkspaceTabBar: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors

    private var routes: [AppRoute] {
        AppRoute.allCases.filter { $0.primaryWorkspace == appState.primaryWorkspace && $0.sidebarVisible }
    }

    var body: some View {
        if routes.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(routes) { route in
                        WorkspaceTab(route: route, isSelected: appState.selectedRoute == route)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 36)
            .overlay(alignment: .bottom) {
                Rectangle().fill(colors.border).frame(height: 1)
            }
        }
    }
}

// MARK: - Single Tab

struct WorkspaceTab: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @State private var isHovering = false

    let route: AppRoute
    let isSelected: Bool

    var body: some View {
        Button {
            withAnimation(PulseAnimation.easeOutFast) {
                appState.selectedRoute = route
            }
        } label: {
            Text(route.label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? KryptonColor.amber : (isHovering ? colors.textSecondary : colors.textMuted))
                .padding(.horizontal, 16)
                .frame(height: 36)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? KryptonColor.amber : .clear)
                        .frame(height: 2)
                        .padding(.horizontal, 2)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) { isHovering = hovering }
        }
    }
}
