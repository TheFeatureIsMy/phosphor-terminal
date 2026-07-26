// APIStrategyWorkspace.swift - Strategy workbench BFF API (7 endpoints).
// Spec §6.1.A–G

import Foundation

struct APIStrategyWorkspace {
    let client: NetworkClientProtocol

    func getSnapshot(strategyId: String) async throws -> WorkspaceSnapshot {
        try await client.get("/api/v2/strategies/\(strategyId)/workspace")
    }

    func duplicate(strategyId: String, name: String?) async throws -> StrategyV2 {
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        return try await client.post("/api/v2/strategies/\(strategyId)/duplicate", body: AnyEncodable(body))
    }

    func listBindings(strategyId: String) async throws -> [StrategyBinding] {
        try await client.get("/api/v2/strategies/\(strategyId)/bindings")
    }

    func createBinding(
        strategyId: String,
        versionId: String,
        policyVersionId: String,
        poolId: String,
        mode: String
    ) async throws -> StrategyBinding {
        let body: [String: Any] = [
            "strategy_version_id": versionId,
            "risk_policy_version_id": policyVersionId,
            "capital_pool_id": poolId,
            "mode": mode,
        ]
        return try await client.post("/api/v2/strategies/\(strategyId)/bindings", body: AnyEncodable(body))
    }

    func deleteBinding(strategyId: String, bindingId: String) async throws {
        try await client.delete("/api/v2/strategies/\(strategyId)/bindings/\(bindingId)")
    }

    func archive(strategyId: String, reason: String?) async throws -> StrategyV2 {
        var body: [String: Any] = [:]
        if let r = reason { body["reason"] = r }
        return try await client.patch("/api/v2/strategies/\(strategyId)/archive", body: AnyEncodable(body))
    }

    func listActivity(strategyId: String, limit: Int = 20) async throws -> [ActivityEntry] {
        try await client.get("/api/v2/strategies/\(strategyId)/activity?limit=\(limit)")
    }
}
