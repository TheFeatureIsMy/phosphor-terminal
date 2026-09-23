// APIStrategyRuns.swift — Strategy Run API (list runs, orders, ledger)

import Foundation

struct APIStrategyRuns {
    let client: NetworkClientProtocol

    func listRuns(
        mode: String? = nil,
        status: String? = nil,
        strategyId: String? = nil,
        strategyVersionId: String? = nil,
        limit: Int = 20
    ) async throws -> [StrategyRunV2] {
        var path = "/api/v2/strategy-runs?limit=\(limit)"
        if let mode { path += "&mode=\(mode)" }
        if let status { path += "&status=\(status)" }
        if let strategyId { path += "&strategy_id=\(strategyId)" }
        if let strategyVersionId { path += "&strategy_version_id=\(strategyVersionId)" }
        return try await client.get(path)
    }

    func getRun(_ id: String) async throws -> StrategyRunV2 {
        try await client.get("/api/v2/strategy-runs/\(id)")
    }

    func getRunOrders(_ runId: String, limit: Int = 50) async throws -> [Order] {
        try await client.get("/api/v2/strategy-runs/\(runId)/orders?limit=\(limit)")
    }

    func getRunLedger(_ runId: String, limit: Int = 50) async throws -> [AnyCodable] {
        try await client.get("/api/v2/strategy-runs/\(runId)/ledger?limit=\(limit)")
    }

    // MARK: - Lifecycle control (pause / resume / stop)

    func pauseRun(_ runId: String, reason: String = "user_requested") async throws -> [String: AnyCodable] {
        try await client.post(
            "/api/v2/strategy-runs/\(runId)/pause",
            body: AnyEncodable(["reason": reason])
        )
    }

    func resumeRun(_ runId: String, reason: String = "user_requested") async throws -> [String: AnyCodable] {
        try await client.post(
            "/api/v2/strategy-runs/\(runId)/resume",
            body: AnyEncodable(["reason": reason])
        )
    }

    func stopRun(_ runId: String, reason: String = "user_requested") async throws -> [String: AnyCodable] {
        try await client.post(
            "/api/v2/strategy-runs/\(runId)/stop",
            body: AnyEncodable(["reason": reason])
        )
    }
}

