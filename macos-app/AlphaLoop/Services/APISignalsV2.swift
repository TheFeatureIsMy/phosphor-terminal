// APISignalsV2.swift - v2 Signal API (CRUD + transitions + conflict + aggregation)

import Foundation

struct APISignalsV2 {
    let client: NetworkClientProtocol

    func createSignal(_ body: [String: Any]) async throws -> SignalV2 {
        try await client.post("/api/v2/signals", body: AnyEncodable(body))
    }

    func listSignals(symbol: String? = nil, status: String? = nil, limit: Int = 50) async throws -> [SignalV2] {
        var path = "/api/v2/signals?limit=\(limit)"
        if let symbol { path += "&symbol=\(symbol)" }
        if let status { path += "&status=\(status)" }
        return try await client.get(path)
    }

    func getSignal(_ id: String) async throws -> SignalV2 {
        try await client.get("/api/v2/signals/\(id)")
    }

    func transitionSignal(_ id: String, targetStatus: String, reason: String? = nil) async throws -> SignalV2 {
        try await client.post(
            "/api/v2/signals/\(id)/transition",
            body: AnyEncodable(["target_status": targetStatus, "reason": reason ?? ""])
        )
    }

    func archiveSignal(_ id: String) async throws -> SignalV2 {
        try await client.post("/api/v2/signals/\(id)/archive", body: AnyEncodable([String: String]()))
    }

    func publishToStrategy(_ id: String) async throws -> AnyCodable {
        try await client.post("/api/v2/signals/\(id)/publish-to-strategy", body: AnyEncodable([String: String]()))
    }

    func conflictCheck(symbol: String, direction: String) async throws -> SignalConflictResult {
        try await client.post(
            "/api/v2/signals/conflict-check",
            body: AnyEncodable(["symbol": symbol, "direction": direction])
        )
    }

    func aggregate(groupBy: String = "symbol") async throws -> SignalAggregateResult {
        try await client.post("/api/v2/signals/aggregate", body: AnyEncodable(["group_by": groupBy]))
    }
}
