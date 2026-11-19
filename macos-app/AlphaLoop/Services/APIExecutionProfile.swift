// APIExecutionProfile.swift — 租户执行运行时配置/健康状态
import Foundation

struct ExecutionProfileInfo: Codable {
    let mode: String
    let freqtrade_url: String?
    let api_username: String?
    let has_credentials: Bool
    let has_exchange_credentials: Bool
    let enabled: Bool
    let max_open_trades: Int
    let runtime_status: String
    let last_health_at: String?
    let last_error: String?
}

struct ExecutionProfileHealth: Codable {
    let configured: Bool
    let reachable: Bool
    let freqtrade_url: String?
    let runtime_status: String?
}

struct APIExecutionProfile {
    let client: NetworkClientProtocol

    func get() async throws -> ExecutionProfileInfo {
        try await client.get("/api/admin/execution-profile")
    }

    func health() async throws -> ExecutionProfileHealth {
        try await client.get("/api/admin/execution-profile/health")
    }
}
