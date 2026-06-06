// NotificationRow.swift — 单条通知行视图
// 显示通知类型图标、标题、消息摘要、相对时间、已读/未读状态

import SwiftUI

struct NotificationRow: View {
    @Environment(PulseColors.self) private var colors
    let notification: AppNotification
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: PulseSpacing.sm) {
                // 左侧严重程度边框
                if !notification.isRead {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(notification.severity.color)
                        .frame(width: 3)
                        .frame(minHeight: 36)
                }

                // 类型图标
                Image(systemName: notification.type.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(notification.type.color)
                    .frame(width: 20)

                // 内容
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        // 严重程度标签
                        Text(notification.severity.label)
                            .font(PulseFonts.micro)
                            .foregroundStyle(notification.severity.color)

                        Text(notification.title)
                            .font(notification.isRead ? PulseFonts.caption : PulseFonts.captionMedium)
                            .foregroundStyle(notification.isRead ? colors.textSecondary : colors.textPrimary)
                            .lineLimit(1)
                    }

                    Text(notification.message)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                        .lineLimit(2)

                    Text(NotificationViewModel.relativeTime(from: notification.createdAt))
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }

                Spacer()

                // 未读指示点
                if !notification.isRead {
                    Circle()
                        .fill(notification.severity.color)
                        .frame(width: 6, height: 6)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, PulseSpacing.xs)
            .padding(.horizontal, PulseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PulseRadii.sm)
                    .fill(isHovering ? colors.surfaceHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(PulseAnimation.easeOutFast) {
                isHovering = hovering
            }
        }
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
}

// MARK: - 预览

