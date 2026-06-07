// APIDataSources.swift — Data Source Management BFF API

import Foundation

// MARK: - Response Types

struct DataSourceItemResponse: Codable, Identifiable {
    var id: String { sourceId }
    let sourceId: String
    let name: String
    let category: String
    var provider: String = ""
    var status: String = "active"
    var lastFetch: String = ""
    var latencyMs: Int = 0
    var freshness: String = "fresh"
    var config: [String: String] = [:]
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case name, category, provider, status, freshness, config
        case sourceId = "source_id"
        case lastFetch = "last_fetch"
        case latencyMs = "latency_ms"
        case reasonCodes = "reason_codes"
    }
}

struct DataSourceManagementBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var sources: [DataSourceItemResponse] = []
    var totalActive: Int = 0
    var totalError: Int = 0

    enum CodingKeys: String, CodingKey {
        case state, sources
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case totalActive = "total_active"
        case totalError = "total_error"
    }
}

// MARK: - API Service

struct APIDataSources {
    let client: NetworkClientProtocol

    func getAll() async throws -> DataSourceManagementBFFResponse {
        try await client.get("/api/data-sources", mock: MockDataSources.all)
    }

    func testConnection(_ sourceId: String) async throws -> [String: String] {
        try await client.post("/api/data-sources/\(sourceId)/test", body: nil as String?) {
            ["status": "ok", "latency_ms": "42"]
        }
    }

    func enable(_ sourceId: String) async throws -> [String: String] {
        try await client.post("/api/data-sources/\(sourceId)/enable", body: nil as String?) {
            ["status": "enabled"]
        }
    }

    func disable(_ sourceId: String) async throws -> [String: String] {
        try await client.post("/api/data-sources/\(sourceId)/disable", body: nil as String?) {
            ["status": "disabled"]
        }
    }
}

// MARK: - Mock

enum MockDataSources {
    static func all() -> DataSourceManagementBFFResponse {
        DataSourceManagementBFFResponse(
            state: "warning",
            reasonCodes: ["one_source_error"],
            availableActions: [
                AvailableActionResponse(type: "test_all", enabled: true, label: "测试所有连接"),
            ],
            sources: [
                DataSourceItemResponse(sourceId: "ds-001", name: "Binance Kline", category: "exchange_kline", provider: "Binance", status: "active", lastFetch: "2026-06-05T15:00:00Z", latencyMs: 45, freshness: "fresh"),
                DataSourceItemResponse(sourceId: "ds-002", name: "Binance Orderbook", category: "orderbook", provider: "Binance", status: "active", lastFetch: "2026-06-05T15:00:01Z", latencyMs: 12, freshness: "fresh"),
                DataSourceItemResponse(sourceId: "ds-003", name: "Binance Funding", category: "funding", provider: "Binance", status: "active", lastFetch: "2026-06-05T14:00:00Z", latencyMs: 85, freshness: "fresh"),
                DataSourceItemResponse(sourceId: "ds-004", name: "CoinGlass OI", category: "open_interest", provider: "CoinGlass", status: "active", lastFetch: "2026-06-05T14:55:00Z", latencyMs: 320, freshness: "fresh"),
                DataSourceItemResponse(sourceId: "ds-005", name: "CryptoNews API", category: "news", provider: "CryptoCompare", status: "error", lastFetch: "2026-06-05T12:00:00Z", latencyMs: 0, freshness: "expired", reasonCodes: ["api_key_expired"]),
                DataSourceItemResponse(sourceId: "ds-006", name: "Whale Alert", category: "whale", provider: "Whale Alert", status: "active", lastFetch: "2026-06-05T14:50:00Z", latencyMs: 200, freshness: "fresh"),
                DataSourceItemResponse(sourceId: "ds-007", name: "Glassnode", category: "on_chain", provider: "Glassnode", status: "inactive", lastFetch: "2026-06-04T00:00:00Z", latencyMs: 0, freshness: "stale"),
                DataSourceItemResponse(sourceId: "ds-008", name: "CryptoCompare Social", category: "social", provider: "CryptoCompare", status: "active", lastFetch: "2026-06-05T14:45:00Z", latencyMs: 150, freshness: "fresh"),
            ],
            totalActive: 6,
            totalError: 1
        )
    }
}
