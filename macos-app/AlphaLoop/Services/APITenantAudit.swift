import Foundation

struct TenantAuditEntry: Codable, Identifiable {
    let id: Int
    let action: String
    let actorUserId: Int?
    let detail: [String: AnyCodable]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, action, detail
        case actorUserId = "actor_user_id"
        case createdAt = "created_at"
    }
}

struct APITenantAudit {
    let client: any NetworkClientProtocol

    func list(limit: Int = 50) async throws -> [TenantAuditEntry] {
        try await client.get("/api/admin/tenant-audit?limit=\(limit)")
    }
}
