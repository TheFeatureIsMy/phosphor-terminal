import Foundation

struct TenantSubscriptionInfo: Codable {
    let plan: String
    let status: String
    let currentPeriodEnd: String?

    enum CodingKeys: String, CodingKey {
        case plan, status
        case currentPeriodEnd = "current_period_end"
    }
}

struct APITenantSubscription {
    let client: any NetworkClientProtocol

    func get() async throws -> TenantSubscriptionInfo {
        try await client.get("/api/admin/tenant-subscription")
    }
}
