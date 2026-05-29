// ToolbarView.swift — 标题栏区域工具栏
// 面包屑、系统指标、时钟、搜索、通知、用户菜单

import SwiftUI

struct ToolbarView: View {
    @Environment(AppState.self) private var appState
    @State private var currentTime = Date()
    @State private var showNotifications = false
    @State private var notificationViewModel = NotificationViewModel(client: MockNetworkClient())

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            // 面包屑
            breadcrumb

            Spacer()

            // 系统指标
            systemMetrics

            // 时钟
            Text(timeString)
                .font(PulseFonts.monoSmall)
                .foregroundStyle(PulseColors.textMuted)
                .onReceive(timer) { time in currentTime = time }

            // 连接状态
            connectionDot

            // 搜索按钮
            Button {
                appState.showCommandPalette.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(PulseColors.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)

            // 通知
            Button {
                showNotifications.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 14))
                        .foregroundStyle(PulseColors.textSecondary)

                    if notificationViewModel.unreadCount > 0 {
                        Text(notificationViewModel.unreadCount > 99 ? "99+" : "\(notificationViewModel.unreadCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(PulseColors.danger)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNotifications) {
                NotificationPopover(viewModel: notificationViewModel)
            }

            // 用户头像
            userMenu
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 48)
        .glassEffect()
        .overlay(
            Rectangle()
                .fill(PulseGlass.surfaceTint)
                .allowsHitTesting(false)
        )
    }

    // MARK: - 面包屑
    private var breadcrumb: some View {
        HStack(spacing: PulseSpacing.xxs) {
            Text("PulseDesk")
                .font(PulseFonts.captionMedium)
                .foregroundStyle(PulseColors.textMuted)

            Text("/")
                .font(PulseFonts.caption)
                .foregroundStyle(PulseColors.textMuted)

            Text(appState.selectedRoute.label)
                .font(PulseFonts.captionMedium)
                .foregroundStyle(PulseColors.textPrimary)
        }
    }

    // MARK: - 系统指标
    private var systemMetrics: some View {
        HStack(spacing: PulseSpacing.md) {
            metricBadge(icon: "cpu", value: "23%")
            metricBadge(icon: "memorychip", value: "512MB")
            metricBadge(icon: "network", value: "12ms")
        }
    }

    private func metricBadge(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(value)
                .font(PulseFonts.monoLabel)
        }
        .foregroundStyle(PulseColors.textMuted)
    }

    // MARK: - 连接状态
    private var connectionDot: some View {
        StatusDot(status: .online)
    }

    // MARK: - 时间字符串
    private var timeString: String {
        timeFormatter.string(from: currentTime)
    }

    // MARK: - 用户菜单
    private var userMenu: some View {
        Menu {
            Button("设置") { appState.selectedRoute = .settings }
            Divider()
            Button("登出") {}
        } label: {
            Circle()
                .fill(PulseColors.accent.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("T")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(PulseColors.accent)
                )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
    }
}
