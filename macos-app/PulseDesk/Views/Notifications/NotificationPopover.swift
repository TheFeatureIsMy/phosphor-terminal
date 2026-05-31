// NotificationPopover.swift — 通知中心弹出视图
// 显示通知列表，支持全部已读和查看全部操作

import SwiftUI

struct NotificationPopover: View {
    @Environment(PulseColors.self) private var colors
    let viewModel: NotificationViewModel
    var onViewAll: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            header

            // 通知列表
            if viewModel.isLoading {
                loadingState
            } else if viewModel.notifications.isEmpty {
                emptyState
            } else {
                notificationList
            }

            // 底部操作栏
            if !viewModel.notifications.isEmpty {
                footer
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 400)
        .background(colors.background)
        .task {
            await viewModel.fetchNotifications()
        }
    }

    // MARK: - 标题栏
    private var header: some View {
        HStack {
            Text("通知中心")
                .font(PulseFonts.bodyMedium)
                .foregroundStyle(colors.textPrimary)

            if viewModel.unreadCount > 0 {
                Text("\(viewModel.unreadCount)")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulseColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(PulseColors.accent.opacity(0.15))
                    )
            }

            Spacer()
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.sm)
        .overlay(
            Rectangle()
                .fill(colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - 通知列表
    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.notifications.prefix(20).enumerated()), id: \.element.id) { index, notification in
                    NotificationRow(notification: notification) {
                        Task {
                            await viewModel.markAsRead(id: notification.id)
                        }
                    }
                    .staggeredAppearance(index: index, baseDelay: 0.02)

                    if index < viewModel.notifications.prefix(20).count - 1 {
                        Divider()
                            .foregroundStyle(colors.border)
                            .padding(.horizontal, PulseSpacing.sm)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    // MARK: - 加载状态
    private var loadingState: some View {
        VStack(spacing: PulseSpacing.sm) {
            ProgressView()
                .tint(PulseColors.accent)
            Text("加载中...")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: PulseSpacing.sm) {
            Image(systemName: "bell.slash")
                .font(.system(size: 24))
                .foregroundStyle(colors.textMuted)
            Text("暂无通知")
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - 底部操作栏
    private var footer: some View {
        HStack {
            Button {
                Task {
                    await viewModel.markAllAsRead()
                }
            } label: {
                Text("全部已读")
                    .font(PulseFonts.captionMedium)
                    .foregroundStyle(PulseColors.accent)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.unreadCount == 0)

            Spacer()

            if let onViewAll {
                Button(action: onViewAll) {
                    Text("查看全部")
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseSpacing.md)
        .padding(.vertical, PulseSpacing.sm)
        .overlay(
            Rectangle()
                .fill(colors.border)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - 预览
#Preview {
    let colors = PulseColors(themeManager: ThemeManager())
    NotificationPopover(
        viewModel: NotificationViewModel(client: MockNetworkClient()),
        onViewAll: {}
    )
    .padding()
    .background(colors.background)
    .environment(colors)
}
