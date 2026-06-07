// OperationsRootView.swift — 系统运维工作区
// 保活 SYSTEM + Agent Platform 全部二级页面

import SwiftUI

struct OperationsRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient

    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                content
            }
        }
        .onChange(of: appState.primaryWorkspace) { _, newValue in
            if newValue == .operations { isVisible = true }
        }
        .onAppear {
            if appState.primaryWorkspace == .operations { isVisible = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selectedRoute {
        case .agentPlatform:
            AgentPlatformView()
        case .serviceManagement:
            AIProvidersView()
        case .dataSourceManagement:
            DataSourcesView()
        case .systemSettings:
            SettingsView()
        default:
            EmptyView()
        }
    }
}
