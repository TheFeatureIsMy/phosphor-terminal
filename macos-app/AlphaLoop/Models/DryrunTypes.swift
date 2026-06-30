// DryrunTypes.swift — Dryrun (live simulation) response models

import Foundation

struct DryRunRunV2: Codable, Identifiable, Hashable {
    let id: Int
    let strategyId: Int
    let strategyVersionId: String?
    let commandId: String?
    let dslHash: String?
    let status: String
    let pid: Int?
    let apiPort: Int?
    let apiUrl: String?
    let symbols: [String]
    let stakeAmount: Double
    let maxOpenTrades: Int
    let initialWallet: Double
    let exchange: String
    let totalTrades: Int
    let openTrades: Int
    let totalProfit: Double
    let errorMessage: String?
    let lastSyncedAt: String?
    let createdAt: String?
    let startedAt: String?
    let stoppedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, symbols, pid, exchange
        case strategyId = "strategy_id"
        case strategyVersionId = "strategy_version_id"
        case commandId = "command_id"
        case dslHash = "dsl_hash"
        case apiPort = "api_port"
        case apiUrl = "api_url"
        case stakeAmount = "stake_amount"
        case maxOpenTrades = "max_open_trades"
        case initialWallet = "initial_wallet"
        case totalTrades = "total_trades"
        case openTrades = "open_trades"
        case totalProfit = "total_profit"
        case errorMessage = "error_message"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
    }
}

struct DryRunSyncResponseV2: Codable, Hashable {
    let dryrunRunId: Int
    let newEvents: Int
    let openTrades: Int
    let closedTrades: Int
    let success: Bool
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case dryrunRunId = "dryrun_run_id"
        case newEvents = "new_events"
        case openTrades = "open_trades"
        case closedTrades = "closed_trades"
        case success
        case errors
    }
}
