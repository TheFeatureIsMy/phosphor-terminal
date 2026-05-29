// NotificationViewModel.swift — 通知视图模型
// 管理通知列表、未读计数、标记已读等状态

import SwiftUI

@Observable
@MainActor
final class NotificationViewModel {
    var notifications: [AppNotification] = []
    var unreadCount: Int = 0
    var isLoading: Bool = false
    var error: String?

    private let api: APINotifications

    init(client: NetworkClientProtocol = MockNetworkClient()) {
        self.api = APINotifications(client: client)
    }

    /// 获取通知列表并更新未读计数
    func fetchNotifications(limit: Int = 20) async {
        isLoading = true
        error = nil
        do {
            notifications = try await api.fetchNotifications(limit: limit)
            updateUnreadCount()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 标记单条通知为已读
    func markAsRead(id: UUID) async {
        do {
            try await api.markAsRead(id: id)
            // 乐观更新本地状态
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                let old = notifications[index]
                notifications[index] = AppNotification(
                    id: old.id,
                    type: old.type,
                    title: old.title,
                    message: old.message,
                    severity: old.severity,
                    isRead: true,
                    actionRoute: old.actionRoute,
                    actionPayload: old.actionPayload,
                    createdAt: old.createdAt
                )
                updateUnreadCount()
            }
        } catch {
            // 静默失败，下次刷新会同步
        }
    }

    /// 标记所有通知为已读
    func markAllAsRead() async {
        do {
            try await api.markAllAsRead()
            // 乐观更新本地状态
            notifications = notifications.map { notification in
                AppNotification(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    message: notification.message,
                    severity: notification.severity,
                    isRead: true,
                    actionRoute: notification.actionRoute,
                    actionPayload: notification.actionPayload,
                    createdAt: notification.createdAt
                )
            }
            unreadCount = 0
        } catch {
            // 静默失败
        }
    }

    /// 刷新未读计数
    func refreshUnreadCount() async {
        do {
            unreadCount = try await api.getUnreadCount()
        } catch {
            // 静默失败
        }
    }

    /// 从本地 notifications 数组更新未读计数
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    /// 相对时间格式化（中文）
    static func relativeTime(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
}
