// GlobalStatusBar.swift — 跨页面顶部全局状态栏

import SwiftUI

struct GlobalStatusBar: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsState.self) private var settingsState
    @Environment(\.networkClient) private var networkClient
    @State private var showNotifications = false
    @State private var notificationViewModel: NotificationViewModel?

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            // 左侧：面包屑
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
            .id(settingsState.language)

            if !appState.isLiveMode {
                HStack(spacing: PulseSpacing.xxs) {
                    StatusDot(status: .warning)
                    Text("MOCK")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.StateColors.yellow)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(PulseColors.StateColors.yellow.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            // 右侧：语言 / 主题 / 搜索 / 通知
            HStack(spacing: PulseSpacing.sm) {
                Button { settingsState.toggleLanguage() } label: {
                    Text(settingsState.language == .zhCN ? "中" : "EN")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .hoverGlassStyle(cornerRadius: PulseRadii.md)
                }
                .buttonStyle(.plain)
                .help(settingsState.language == .zhCN ? "Switch to English" : "切换到中文")

                Button { themeManager.toggle() } label: {
                    Image(systemName: themeManager.current == .dark ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .hoverGlassStyle(cornerRadius: PulseRadii.md)
                }
                .buttonStyle(.plain)
                .help(themeManager.current == .dark ? L10n.zh("切换明亮模式", en: "Light mode") : L10n.zh("切换暗黑模式", en: "Dark mode"))

                Button { appState.showCommandPalette.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 24, height: 24)
                        .hoverGlassStyle(cornerRadius: PulseRadii.md)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("k", modifiers: .command)
                .help(L10n.zh("搜索 (⌘K)", en: "Search (⌘K)"))

                Button { showNotifications.toggle() } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textMuted)
                            .frame(width: 24, height: 24)
                            .hoverGlassStyle(cornerRadius: PulseRadii.md)
                        if let vm = notificationViewModel, vm.unreadCount > 0 {
                            Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                                .font(PulseFonts.micro)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(PulseColors.danger))
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotifications) {
                    if let vm = notificationViewModel {
                        NotificationPopover(viewModel: vm) {
                            showNotifications = false
                            appState.selectedRoute = .systemSettings
                        }
                    }
                }
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
        }
        .task {
            if notificationViewModel == nil {
                notificationViewModel = NotificationViewModel(client: networkClient)
            }
        }
    }
}
