// APIDryrunV2.swift — v2 Dryrun API (start, stop, status, list)

import Foundation

struct APIDryrunV2 {
    let client: NetworkClientProtocol

    func startDryrun(_ body: [String: Any]) async throws -> DryRunCommandResponse {
        try await client.post("/api/v2/dryrun", body: AnyEncodable(body),
            mock: { MockDryrunV2.startResponse })
    }

    func stopDryrun(_ id: String) async throws -> DryRunCommandResponse {
        try await client.post("/api/v2/dryrun/\(id)/stop", body: AnyEncodable([String: String]()),
            mock: { MockDryrunV2.stopResponse(commandId: id) })
    }

    func getDryrunStatus(_ commandId: String) async throws -> DryRunStatusV2 {
        try await client.get("/api/v2/dryrun/status/\(commandId)",
            mock: { MockDryrunV2.status(commandId: commandId) })
    }

    func listDryruns(
        strategyId: String? = nil,
        strategyVersionId: String? = nil,
        limit: Int = 20
    ) async throws -> [DryRunStatusV2] {
        var path = "/api/v2/dryrun?limit=\(limit)"
        if let strategyId { path += "&strategy_id=\(strategyId)" }
        if let strategyVersionId { path += "&strategy_version_id=\(strategyVersionId)" }
        return try await client.get(path, mock: MockDryrunV2.list)
    }

    func getDryrun(_ id: Int) async throws -> DryRunRunV2 {
        try await client.get("/api/v2/dryrun/\(id)",
            mock: { MockDryrunV2.detail(id: id) })
    }

    func syncDryrun(_ id: Int) async throws -> DryRunSyncResponseV2 {
        try await client.post("/api/v2/dryrun/\(id)/sync", body: AnyEncodable([String: String]()),
            mock: { MockDryrunV2.sync(id: id) })
    }
}

enum MockDryrunV2 {
    static var startResponse: DryRunCommandResponse {
        DryRunCommandResponse(commandId: UUID().uuidString, status: "pending")
    }

    static func stopResponse(commandId: String) -> DryRunCommandResponse {
        DryRunCommandResponse(commandId: commandId, status: "stopping")
    }

    static func status(commandId: String) -> DryRunStatusV2 {
        DryRunStatusV2(commandId: commandId, status: "running", result: AnyCodable([
            "run_id": UUID().uuidString,
            "strategy_name": "RSI Mean Reversion",
            "symbol": "BTC/USDT",
            "exchange": "binance",
            "started_at": "2026-06-05T08:00:00Z",
            "total_trades": 5,
            "win_rate": 0.60,
            "total_pnl": 128.45,
            "current_balance": 10128.45,
        ] as [String: Any]))
    }

    static func detail(id: Int) -> DryRunRunV2 {
        DryRunRunV2(
            id: id, strategyId: 1, strategyVersionId: nil, commandId: UUID().uuidString,
            dslHash: "a1b2c3d4", status: "running", pid: 12345, apiPort: 8081, apiUrl: "http://127.0.0.1:8081",
            symbols: ["BTC/USDT"], stakeAmount: 100, maxOpenTrades: 5, initialWallet: 10000,
            exchange: "binance", totalTrades: 5, openTrades: 2, totalProfit: 12.5,
            errorMessage: nil, lastSyncedAt: "2026-06-30T00:00:30Z",
            createdAt: "2026-06-30T00:00:00Z", startedAt: "2026-06-30T00:00:05Z",
            stoppedAt: nil
        )
    }

    static func sync(id: Int) -> DryRunSyncResponseV2 {
        DryRunSyncResponseV2(dryrunRunId: id, newEvents: 3, openTrades: 2, closedTrades: 3, success: true, errors: [])
    }

    static func list() -> [DryRunStatusV2] {
        [
            status(commandId: UUID().uuidString),
            DryRunStatusV2(commandId: UUID().uuidString, status: "completed", result: AnyCodable([
                "strategy_name": "MACD Crossover", "symbol": "ETH/USDT", "exchange": "binance",
                "total_trades": 18, "win_rate": 0.56, "total_pnl": 312.70,
            ] as [String: Any])),
            DryRunStatusV2(commandId: UUID().uuidString, status: "error", result: AnyCodable([
                "strategy_name": "Bollinger Breakout", "symbol": "SOL/USDT",
                "error_code": "INSUFFICIENT_BALANCE",
                "error_message": "Insufficient balance for initial stake amount",
            ] as [String: Any])),
        ]
    }
}
