// APIBacktestV2.swift — v2 strong-typed backtest API
// Methods on NetworkClientProtocol + mock factories in MockDataV2
// Uses existing client.get/post mock-closure pattern.

import Foundation

// MARK: - Request/Response types

struct StartBacktestV2Request: Encodable {
    let dsl: [String: String]
    let timerange: String
    let symbols: [String]
    let initial_capital: Double
    let stake_amount: Double
    let max_open_trades: Int
    let exchange: String
    let fee: Double?
    let slippage_bps: Double?
    let strategy_id: Int
    let strategy_version_id: String?

    enum CodingKeys: String, CodingKey {
        case dsl, timerange, symbols, exchange, fee
        case initial_capital, stake_amount, max_open_trades
        case slippage_bps, strategy_id, strategy_version_id
    }
}

struct BacktestCommandResponseV2: Decodable, Hashable {
    let commandId: String
    let status: String
    let message: String
    let idempotencyKey: String

    enum CodingKeys: String, CodingKey {
        case status, message
        case commandId = "command_id"
        case idempotencyKey = "idempotency_key"
    }
}

struct BacktestStatusResponseV2: Decodable, Hashable {
    let commandId: String
    let commandStatus: String
    let backtestRun: BacktestRunV2?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case commandStatus = "command_status"
        case backtestRun = "backtest_run"
        case errorMessage = "error_message"
    }
}

// MARK: - NetworkClientProtocol extension

extension NetworkClientProtocol {

    func startBacktestV2(
        dsl: [String: String],
        timerange: String,
        symbols: [String],
        initialCapital: Double,
        stakeAmount: Double = 100,
        maxOpenTrades: Int = 5,
        exchange: String = "binance",
        fee: Double? = nil,
        slippageBps: Double? = nil,
        strategyId: Int = 0,
        strategyVersionId: String? = nil
    ) async throws -> BacktestCommandResponseV2 {
        let req = StartBacktestV2Request(
            dsl: dsl, timerange: timerange, symbols: symbols,
            initial_capital: initialCapital, stake_amount: stakeAmount,
            max_open_trades: maxOpenTrades, exchange: exchange,
            fee: fee, slippage_bps: slippageBps,
            strategy_id: strategyId, strategy_version_id: strategyVersionId
        )
        return try await post("/api/v2/backtest", body: req) {
            MockDataV2.mockBacktestCommandResponseV2()
        }
    }

    func backtestStatusV2(commandId: String) async throws -> BacktestStatusResponseV2 {
        try await get("/api/v2/backtest/status/\(commandId)") {
            MockDataV2.mockBacktestStatusResponseV2()
        }
    }

    func listBacktestsV2(strategyUuid: String? = nil, limit: Int = 20) async throws -> [BacktestRunV2] {
        var path = "/api/v2/backtest?limit=\(limit)"
        if let uuid = strategyUuid { path += "&strategy_uuid=\(uuid)" }
        return try await get(path) { [] }
    }

    func getBacktestV2(id: Int) async throws -> BacktestRunV2 {
        try await get("/api/v2/backtest/\(id)") {
            MockDataV2.mockBacktestRunV2(id: id)
        }
    }
}

// MARK: - Mock factories

extension MockDataV2 {
    static func mockBacktestCommandResponseV2() -> BacktestCommandResponseV2 {
        BacktestCommandResponseV2(
            commandId: UUID().uuidString,
            status: "queued",
            message: "mock backtest command enqueued",
            idempotencyKey: UUID().uuidString
        )
    }

    static func mockBacktestStatusResponseV2() -> BacktestStatusResponseV2 {
        BacktestStatusResponseV2(
            commandId: UUID().uuidString,
            commandStatus: "completed",
            backtestRun: MockDataV2.mockBacktestRunV2(id: 1),
            errorMessage: nil
        )
    }

    static func mockBacktestRunV2(id: Int) -> BacktestRunV2 {
        // Returns a single run for "local echo after new run"; listBacktestsV2 does NOT call this.
        BacktestRunV2(
            id: id,
            strategyId: 1,
            strategyVersionId: nil,
            commandId: UUID().uuidString,
            dslHash: "mock",
            status: "completed",
            startDate: "20240101",
            endDate: "20240601",
            initialCapital: 10000,
            symbols: ["BTC/USDT"],
            config: [:],
            result: [:],
            sharpeRatio: 1.8,
            maxDrawdown: -0.12,
            winRate: 0.55,
            totalReturn: 0.12,
            profitFactor: 1.6,
            totalTrades: 42,
            errorMessage: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            completedAt: ISO8601DateFormatter().string(from: Date()),
            equityCurve: [
                BacktestEquityPoint(timestamp: "2024-01-01", equity: 10000, drawdown: 0),
                BacktestEquityPoint(timestamp: "2024-06-01", equity: 11200, drawdown: -0.05),
            ],
            trades: []
        )
    }
}
