// APIStrategiesV2.swift — v2.5 Strategy API (CRUD + versions + DSL validation + backtest)

import Foundation

final class APIStrategiesV2: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - Strategy CRUD

    func list() async throws -> [StrategyV2] {
        try await client.get("/api/v2/strategies", mock: { MockDataV2.strategies() })
    }

    func get(id: String) async throws -> StrategyV2 {
        try await client.get("/api/v2/strategies/\(id)", mock: { MockDataV2.strategies().first! })
    }

    func create(name: String, strategyType: String = "rule_dsl", sourceType: String = "manual") async throws -> StrategyV2 {
        try await client.post("/api/v2/strategies", body: [
            "name": name,
            "strategy_type": strategyType,
            "source_type": sourceType,
        ], mock: {
            StrategyV2(
                id: UUID().uuidString,
                name: name,
                description: nil,
                strategyType: strategyType,
                sourceType: sourceType,
                status: "draft",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        })
    }

    func deleteStrategy(id: String) async throws {
        try await client.delete("/api/v2/strategies/\(id)", mock: { })
    }

    func updateStrategy(id: String, name: String) async throws -> StrategyV2 {
        try await client.patch("/api/v2/strategies/\(id)", body: ["name": name], mock: {
            StrategyV2(
                id: id,
                name: name,
                description: nil,
                strategyType: "rule_dsl",
                sourceType: "manual",
                status: "draft",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        })
    }

    // MARK: - Versions

    func listVersions(strategyId: String) async throws -> [StrategyVersionV2] {
        try await client.get("/api/v2/strategies/\(strategyId)/versions", mock: { [] })
    }

    func createVersion(strategyId: String, ruleDsl: [String: Any]) async throws -> StrategyVersionV2 {
        try await client.post(
            "/api/v2/strategies/\(strategyId)/versions",
            body: AnyEncodable(["rule_dsl": ruleDsl]),
            mock: {
                StrategyVersionV2(
                    id: UUID().uuidString,
                    strategyId: strategyId,
                    versionNo: 1,
                    status: "draft",
                    dslVersion: "2.5",
                    ruleDsl: [:],
                    dslHash: "mock",
                    createdBy: "user",
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
            }
        )
    }

    // MARK: - DSL Validation

    func validateDSL(_ dsl: [String: Any]) async throws -> DSLValidationReport {
        try await client.post(
            "/api/v2/strategies/validate-dsl",
            body: AnyEncodable(["dsl": dsl]),
            mock: {
                DSLValidationReport(
                    valid: true, errorCount: 0, warningCount: 0,
                    safeHoldRequired: false, safeHoldReasons: [],
                    errors: [], warnings: []
                )
            }
        )
    }

    // MARK: - Backtest (Command Bus)

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
        return try await client.post(
            "/api/v2/backtest",
            body: AnyEncodable(body),
            mock: {
                BacktestCommandResponse(
                    commandId: UUID().uuidString,
                    status: "pending",
                    message: "backtest command enqueued",
                    idempotencyKey: "mock"
                )
            }
        )
    }

    func backtestStatus(commandId: String) async throws -> BacktestStatusV2 {
        try await client.get("/api/v2/backtest/status/\(commandId)", mock: {
            BacktestStatusV2Mock.completed()
        })
    }

    func listBacktests(strategyId: Int? = nil, limit: Int = 20) async throws -> [BacktestRunV2] {
        var path = "/api/v2/backtest?limit=\(limit)"
        if let sid = strategyId { path += "&strategy_id=\(sid)" }
        return try await client.get(path, mock: { [] })
    }
}

// MARK: - Mock data for v2.5

enum MockDataV2 {
    static func strategies() -> [StrategyV2] {
        [
            StrategyV2(id: UUID().uuidString, name: "RSI 均值回归", description: "RSI < 30 入场", strategyType: "rule_dsl", sourceType: "manual", status: "draft", createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"),
        ]
    }
}

enum BacktestStatusV2Mock {
    static func completed() -> BacktestStatusV2 {
        // Provide a simple mock for offline/mock mode
        let decoder = JSONDecoder()
        let json = """
        {"command_id":"00000000-0000-0000-0000-000000000000","command_status":"completed","backtest_run":null,"error_code":null,"error_message":null}
        """.data(using: .utf8)!
        return try! decoder.decode(BacktestStatusV2.self, from: json)
    }
}
