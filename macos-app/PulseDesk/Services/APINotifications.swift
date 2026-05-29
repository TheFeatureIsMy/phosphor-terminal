// APINotifications.swift — 通知相关 API

import Foundation

/// PUT 端点返回的简单确认响应
struct AckResponse: Decodable {
    let ok: Bool
}

struct APINotifications {
    let client: NetworkClientProtocol

    func fetchNotifications(limit: Int = 20) async throws -> [AppNotification] {
        try await client.get("/api/notifications?limit=\(limit)", mock: MockData.mockNotifications)
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
        try await client.get("/api/notifications/unread-count", mock: {
            MockData.mockNotifications().filter { !$0.isRead }.count
        })
    }
}
