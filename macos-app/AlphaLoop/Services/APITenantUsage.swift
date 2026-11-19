import Foundation

struct TenantUsageInfo: Codable {
    struct Limits: Codable {
        let members: Int
        let strategies: Int
        let auditDays: Int?

        enum CodingKeys: String, CodingKey {
            case members, strategies, auditDays = "audit_days"
        }
    }
    struct Usage: Codable {
        let members: Int
        let strategies: Int
        let auditLogs: Int
        let activeSessions: Int

        enum CodingKeys: String, CodingKey {
            case members, strategies
            case auditLogs = "audit_logs"
            case activeSessions = "active_sessions"
        }
    }
    struct Warning: Codable {
        let resource: String
        let used: Int
        let limit: Int
    }
    let plan: String
    let limits: Limits
    let usage: Usage
    let warnings: [Warning]?
}

struct APITenantUsage {
    let client: any NetworkClientProtocol

    func get() async throws -> TenantUsageInfo {
        try await client.get("/api/admin/tenant-usage")
    }
}
