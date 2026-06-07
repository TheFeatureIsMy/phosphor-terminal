// AppShellView.swift — Krypton Pro 主布局壳
// 深色交易终端：侧边栏、状态栏、内容区是同一终端表面的功能分区

import SwiftUI

struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(ToastManager.self) private var toastManager

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebarSection

                VStack(spacing: 0) {
                    GlobalStatusBar()
                    WorkspaceTabBar()
                    workspaceContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background {
            ZStack {
                colors.background
                // Phase 1 背景降级：保留静态背景层，后续 Phase 3 进一步简化
                Rectangle().fill(KryptonColor.amberSpotlight.opacity(0.12))
                Rectangle().fill(colors.cardBackground.opacity(0.72))
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
    }

    // MARK: - 3 工作区保活 (ZStack, 无 .id 销毁)

    @ViewBuilder
    private var workspaceContent: some View {
        ZStack {
            TradingConsoleRootView()
                .opacity(appState.primaryWorkspace == .tradingConsole ? 1 : 0)
                .allowsHitTesting(appState.primaryWorkspace == .tradingConsole)

            StrategyLabRootView()
                .opacity(appState.primaryWorkspace == .strategyLab ? 1 : 0)
                .allowsHitTesting(appState.primaryWorkspace == .strategyLab)

            OperationsRootView()
                .opacity(appState.primaryWorkspace == .operations ? 1 : 0)
                .allowsHitTesting(appState.primaryWorkspace == .operations)
        }
    }

    // MARK: - 侧边栏区域 — 同一表面的子区域
    private var sidebarSection: some View {
        SidebarView()
    }
}
