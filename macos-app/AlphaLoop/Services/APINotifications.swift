// APINotifications.swift — 通知相关 API

import Foundation

/// PUT 端点返回的简单确认响应
struct AckResponse: Decodable {
    let ok: Bool
}

/// 后端 GET /notifications 返回的包装结构
struct NotificationsResponse: Decodable {
    let notifications: [BackendNotification]
    let unread: Int
}

/// 后端通知的原始 JSON 结构（与 AppNotification 字段不完全匹配）
struct BackendNotification: Decodable {
    let id: Int
    let type: String?
    let title: String
    let message: String
    let read: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, read
        case createdAt = "created_at"
    }

    /// 转换为 AppNotification
    func toAppNotification() -> AppNotification {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", id))") ?? UUID()
        let notifType = type.flatMap { NotificationType(rawValue: $0) } ?? .systemAlert
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = createdAt.flatMap { dateFormatter.date(from: $0) }
            ?? ISO8601DateFormatter().date(from: createdAt ?? "")
            ?? Date()

        return AppNotification(
            id: uuid,
            type: notifType,
            title: title,
            message: message,
            severity: .info,
            isRead: read,
            actionRoute: nil,
            actionPayload: nil,
            createdAt: date
        )
    }
}

/// Telegram 测试结果
struct HealthCheckResult: Decodable {
    let success: Bool
    let status: String
    let latencyMs: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, status
        case latencyMs = "latency_ms"
        case error
    }
}

struct APINotifications {
    let client: NetworkClientProtocol

    func fetchNotifications(limit: Int = 20) async throws -> [AppNotification] {
        let response: NotificationsResponse = try await client.get(
            "/api/notifications?limit=\(limit)",
            mock: { NotificationsResponse(notifications: [], unread: MockData.mockNotifications().filter { !$0.isRead }.count) }
        )
        return response.notifications.map { $0.toAppNotification() }
    }

    @discardableResult
    func markAsRead(id: UUID) async throws -> AckResponse {
        try await client.put("/api/notifications/\(id.uuidString)/read", body: nil as String?, mock: { AckResponse(ok: true) })
    }

    @discardableResult
    func markAllAsRead() async throws -> AckResponse {
        try await client.put("/api/notifications/read-all", body: nil as String?, mock: { AckResponse(ok: true) })
    }

    func getUnreadCount() async throws -> Int {
        let response: NotificationsResponse = try await client.get(
            "/api/notifications?limit=1",
            mock: { NotificationsResponse(notifications: [], unread: MockData.mockNotifications().filter { !$0.isRead }.count) }
        )
        return response.unread
    }

    /// POST /api/admin/providers/test — Telegram connection test
    func telegramTest(botToken: String, chatId: String, dryRun: Bool) async throws -> HealthCheckResult {
        struct TelegramTestBody: Encodable {
            let category: String
            let providerName: String
            let credentials: [String: String]
            let config: [String: Bool]

            enum CodingKeys: String, CodingKey {
                case category, credentials, config
                case providerName = "provider_name"
            }
        }
        return try await client.post("/api/admin/providers/test", body: TelegramTestBody(
            category: "notification",
            providerName: "telegram",
            credentials: ["bot_token": botToken, "chat_id": chatId],
            config: ["dry_run": dryRun]
        ), mock: {
            HealthCheckResult(success: true, status: "active", latencyMs: 120, error: nil)
        })
    }
}
