// APIBacktestV2.swift — v2 strong-typed backtest API
// Methods on NetworkClientProtocol + mock factories in MockBacktest
// Uses existing client.get/post mock-closure pattern.

import Foundation

// MARK: - Request/Response types

struct StartBacktestV2Request: Encodable {
    let dsl: [String: AnyCodable]
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

// MARK: - NetworkClientProtocol extension

extension NetworkClientProtocol {

    func startBacktestV2(
        dsl: [String: AnyCodable],
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
            MockBacktest.commandResponse()
        }
    }

    func backtestStatusV2(commandId: String) async throws -> BacktestStatusV2 {
        try await get("/api/v2/backtest/status/\(commandId)") {
            MockBacktest.status(commandId: commandId)
        }
    }

    func listBacktestsV2(strategyUuid: String? = nil, limit: Int = 20) async throws -> [BacktestRunV2] {
        var path = "/api/v2/backtest?limit=\(limit)"
        if let uuid = strategyUuid { path += "&strategy_uuid=\(uuid)" }
        return try await get(path) { [] }
    }

    func getBacktestV2(id: Int) async throws -> BacktestRunV2 {
        try await get("/api/v2/backtest/\(id)") {
            MockBacktest.run(id: id)
        }
    }
}

