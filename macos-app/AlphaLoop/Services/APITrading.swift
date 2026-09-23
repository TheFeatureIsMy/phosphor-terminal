// APITrading.swift - Trading control endpoints (PRD Live Readiness execution entries)
// POST /api/trading/start-paper · start-live-small · disable-auto

import Foundation

// MARK: - Responses

struct TradingCommandResponse: Codable {
    let state: String
    let reasonCodes: [String]
    let commandId: String?
    let commandStatus: String?
    let idempotencyKey: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case state
        case reasonCodes = "reason_codes"
        case commandId = "command_id"
        case commandStatus = "command_status"
        case idempotencyKey = "idempotency_key"
        case message
    }
}

struct TradingPreconditionItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let passed: Bool
    let reason: String?
}

struct TradingPreconditionReport: Codable {
    let allPassed: Bool
    let items: [TradingPreconditionItem]

    enum CodingKeys: String, CodingKey {
        case allPassed = "all_passed"
        case items
    }
}

struct StartLiveSmallResponse: Codable {
    let state: String
    let reasonCodes: [String]
    let commandId: String?
    let commandStatus: String?
    let canProceed: Bool
    let liveSmallEnabled: Bool
    let preconditions: TradingPreconditionReport?
    let riskErrors: [RiskErrorRef]?

    enum CodingKeys: String, CodingKey {
        case state
        case reasonCodes = "reason_codes"
        case commandId = "command_id"
        case commandStatus = "command_status"
        case canProceed = "can_proceed"
        case liveSmallEnabled = "live_small_enabled"
        case preconditions
        case riskErrors = "risk_errors"
    }
}

struct RiskErrorRef: Codable, Identifiable {
    var id: String { code }
    let code: String
    let message: String?
}

struct DisableAutoResponse: Codable {
    let state: String
    let reasonCodes: [String]
    let stoppedDryruns: Int
    let firewallActive: Bool

    enum CodingKeys: String, CodingKey {
        case state
        case reasonCodes = "reason_codes"
        case stoppedDryruns = "stopped_dryruns"
        case firewallActive = "firewall_active"
    }
}

// MARK: - Requests

struct StartPaperBody: Encodable {
    let strategyVersionId: String
    let symbols: [String]
    let stakeAmount: Double
    let maxOpenTrades: Int
    let initialWallet: Double
    let exchange: String

    enum CodingKeys: String, CodingKey {
        case strategyVersionId = "strategy_version_id"
        case symbols
        case stakeAmount = "stake_amount"
        case maxOpenTrades = "max_open_trades"
        case initialWallet = "initial_wallet"
        case exchange
    }
}

struct StartLiveSmallBody: Encodable {
    let strategyVersionId: String
    let capitalPoolId: String
    let exchangeName: String
    let humanConfirmed: Bool
    let confirmedBy: String

    enum CodingKeys: String, CodingKey {
        case strategyVersionId = "strategy_version_id"
        case capitalPoolId = "capital_pool_id"
        case exchangeName = "exchange_name"
        case humanConfirmed = "human_confirmed"
        case confirmedBy = "confirmed_by"
    }
}

// MARK: - API

final class APITrading: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    /// Start paper trading (Freqtrade dry-run via Command Bus).
    func startPaper(
        strategyVersionId: String,
        symbols: [String] = ["BTC/USDT"],
        stakeAmount: Double = 100,
        maxOpenTrades: Int = 5,
        initialWallet: Double = 10000,
        exchange: String = "binance"
    ) async throws -> TradingCommandResponse {
        let body = StartPaperBody(
            strategyVersionId: strategyVersionId,
            symbols: symbols,
            stakeAmount: stakeAmount,
            maxOpenTrades: maxOpenTrades,
            initialWallet: initialWallet,
            exchange: exchange
        )
        return try await client.post("/api/trading/start-paper", body: body)
    }

    /// Start live_small — full safety gate chain; requires explicit human confirmation.
    func startLiveSmall(
        strategyVersionId: String,
        capitalPoolId: String,
        exchangeName: String = "binance",
        confirmedBy: String
    ) async throws -> StartLiveSmallResponse {
        let body = StartLiveSmallBody(
            strategyVersionId: strategyVersionId,
            capitalPoolId: capitalPoolId,
            exchangeName: exchangeName,
            humanConfirmed: true,
            confirmedBy: confirmedBy
        )
        return try await client.post("/api/trading/start-live-small", body: body)
    }

    /// Disable automated trading: stops active dry-runs and blocks new entries.
    func disableAuto(reason: String = "manual_disable") async throws -> DisableAutoResponse {
        try await client.post("/api/trading/disable-auto", body: AnyEncodable(["reason": reason]))
    }
}
