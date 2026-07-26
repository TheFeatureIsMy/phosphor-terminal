// APIDryrunV2.swift — v2 Dryrun API (start, stop, status, list)

import Foundation

struct APIDryrunV2 {
    let client: NetworkClientProtocol

    func startDryrun(_ body: [String: Any]) async throws -> DryRunCommandResponse {
        try await client.post("/api/v2/dryrun", body: AnyEncodable(body))
    }

    func stopDryrun(_ id: String) async throws -> DryRunCommandResponse {
        try await client.post("/api/v2/dryrun/\(id)/stop", body: AnyEncodable([String: String]()))
    }

    func getDryrunStatus(_ commandId: String) async throws -> DryRunStatusV2 {
        try await client.get("/api/v2/dryrun/status/\(commandId)")
    }

    func listDryruns(
        strategyId: String? = nil,
        strategyVersionId: String? = nil,
        limit: Int = 20
    ) async throws -> [DryRunRunV2] {
        var path = "/api/v2/dryrun?limit=\(limit)"
        if let strategyId { path += "&strategy_id=\(strategyId)" }
        if let strategyVersionId { path += "&strategy_version_id=\(strategyVersionId)" }
        return try await client.get(path)
    }

    func getDryrun(_ id: Int) async throws -> DryRunRunV2 {
        try await client.get("/api/v2/dryrun/\(id)")
    }

    func syncDryrun(_ id: Int) async throws -> DryRunSyncResponseV2 {
        try await client.post("/api/v2/dryrun/\(id)/sync", body: AnyEncodable([String: String]()))
    }
}

