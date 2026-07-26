// APIStrategiesV2.swift - v2.5 Strategy API (CRUD + versions + DSL validation + backtest)

import Foundation

final class APIStrategiesV2: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func list() async throws -> [StrategyV2] {
        try await client.get("/api/v2/strategies")
    }

    func get(id: String) async throws -> StrategyV2 {
        try await client.get("/api/v2/strategies/\(id)")
    }

    func create(name: String, strategyType: String = "rule_dsl", sourceType: String = "manual") async throws -> StrategyV2 {
        try await client.post("/api/v2/strategies", body: [
            "name": name,
            "strategy_type": strategyType,
            "source_type": sourceType,
        ])
    }

    func deleteStrategy(id: String) async throws {
        try await client.delete("/api/v2/strategies/\(id)")
    }

    func updateStrategy(id: String, name: String) async throws -> StrategyV2 {
        try await client.patch("/api/v2/strategies/\(id)", body: ["name": name])
    }

    func listVersions(strategyId: String) async throws -> [StrategyVersionV2] {
        try await client.get("/api/v2/strategies/\(strategyId)/versions")
    }

    func createVersion(strategyId: String, ruleDsl: [String: Any]) async throws -> StrategyVersionV2 {
        try await client.post("/api/v2/strategies/\(strategyId)/versions", body: AnyEncodable(["rule_dsl": ruleDsl]))
    }

    func transitionVersionStatus(strategyId: String, versionId: String, toStatus: String) async throws -> StrategyVersionV2 {
        try await client.patch("/api/v2/strategies/\(strategyId)/versions/\(versionId)/status", body: ["to_status": toStatus])
    }

    func validateDSL(_ dsl: [String: Any]) async throws -> DSLValidationReport {
        try await client.post("/api/v2/strategies/validate-dsl", body: AnyEncodable(["dsl": dsl]))
    }

    func startBacktest(
        dsl: [String: Any],
        timerange: String,
        symbols: [String],
        initialCapital: Double,
        stakeAmount: Double = 100,
        maxOpenTrades: Int = 5,
        exchange: String = "binance",
        strategyId: Int = 0,
        strategyVersionId: String? = nil
    ) async throws -> BacktestCommandResponse {
        var body: [String: Any] = [
            "dsl": dsl,
            "timerange": timerange,
            "symbols": symbols,
            "initial_capital": initialCapital,
            "stake_amount": stakeAmount,
            "max_open_trades": maxOpenTrades,
            "exchange": exchange,
            "strategy_id": strategyId,
        ]
        if let svid = strategyVersionId {
            body["strategy_version_id"] = svid
        }
        return try await client.post("/api/v2/backtest", body: AnyEncodable(body))
    }

    func backtestStatus(commandId: String) async throws -> BacktestStatusV2 {
        try await client.get("/api/v2/backtest/status/\(commandId)")
    }

    func listBacktests(strategyId: Int? = nil, strategyUuid: String? = nil, limit: Int = 20) async throws -> [BacktestRunV2] {
        var path = "/api/v2/backtest?limit=\(limit)"
        if let sid = strategyId { path += "&strategy_id=\(sid)" }
        if let uuid = strategyUuid { path += "&strategy_uuid=\(uuid)" }
        return try await client.get(path)
    }
}
