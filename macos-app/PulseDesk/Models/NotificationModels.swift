// NotificationModels.swift — 通知系统领域模型

import Foundation

// MARK: - 应用通知
struct AppNotification: Codable, Identifiable, Hashable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let severity: NotificationSeverity
    var isRead: Bool
    let actionRoute: String?
    let actionPayload: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, severity
        case isRead = "is_read"
        case actionRoute = "action_route"
        case actionPayload = "action_payload"
        case createdAt = "created_at"
    }

    /// 将 actionRoute 字符串转换为 AppRoute 枚举
    var route: AppRoute? {
        guard let actionRoute else { return nil }
        return AppRoute(rawValue: actionRoute)
    }
}
