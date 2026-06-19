// APIRiskBFF.swift — Risk BFF API

import Foundation

// MARK: - Response Types

struct RiskGuardResponse: Codable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    var currentValue: Double = 0
    var limitValue: Double = 0
    var remainingPct: Double = 1.0
    var status: String = "healthy"
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case key, label, status
        case currentValue = "current_value"
        case limitValue = "limit_value"
        case remainingPct = "remaining_pct"
        case reasonCodes = "reason_codes"
    }
}

struct RiskOverviewBFFResponse: Codable {
    var state: String = "normal"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var accountState: String = "normal"
    var emergencyLocked: Bool = false
    var guards: [RiskGuardResponse] = []
    var activeLocks: [[String: String]] = []

    enum CodingKeys: String, CodingKey {
        case state, guards
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case accountState = "account_state"
        case emergencyLocked = "emergency_locked"
        case activeLocks = "active_locks"
    }
}

struct StopLevelResponse: Codable {
    var rawStructureStop: Double?
    var lastKnownGoodStop: Double?
    var secureRuntimeStop: Double?
    var exchangeProtectiveStop: Double?
    var volatilityLocked: Bool = false

    enum CodingKeys: String, CodingKey {
        case rawStructureStop = "raw_structure_stop"
        case lastKnownGoodStop = "last_known_good_stop"
        case secureRuntimeStop = "secure_runtime_stop"
        case exchangeProtectiveStop = "exchange_protective_stop"
        case volatilityLocked = "volatility_locked"
    }
}

struct PositionStopResponse: Codable, Identifiable {
    var id: String { positionId }
    let positionId: String
    let symbol: String
    let side: String
    var entryPrice: Double = 0
    var currentPrice: Double = 0
    var stops: StopLevelResponse = StopLevelResponse()
    var stopUpdateAllowed: Bool = true
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case symbol, side, stops
        case positionId = "position_id"
        case entryPrice = "entry_price"
        case currentPrice = "current_price"
        case stopUpdateAllowed = "stop_update_allowed"
        case reasonCodes = "reason_codes"
    }
}

struct StopProtectionBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var positions: [PositionStopResponse] = []
    var volatilityLocks: [[String: String]] = []

    enum CodingKeys: String, CodingKey {
        case state, positions
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case volatilityLocks = "volatility_locks"
    }
}

struct CircuitBreakerRecordResponse: Codable, Identifiable {
    let id: String
    let type: String
    var accountId: String = ""
    var strategyId: String = ""
    var reasonCodes: [String] = []
    var relatedCommandId: String?
    var relatedReconciliationId: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case accountId = "account_id"
        case strategyId = "strategy_id"
        case reasonCodes = "reason_codes"
        case relatedCommandId = "related_command_id"
        case relatedReconciliationId = "related_reconciliation_id"
        case createdAt = "created_at"
    }
}

struct CircuitBreakersBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var records: [CircuitBreakerRecordResponse] = []
    var totalCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case state, records
        case reasonCodes = "reason_codes"
        case totalCount = "total_count"
    }
}

// MARK: - API Service

struct APIRiskBFF {
    let client: NetworkClientProtocol

    func getOverview(strategyId: String? = nil) async throws -> RiskOverviewBFFResponse {
        var path = "/api/risk/overview"
        if let strategyId { path += "?strategy_id=\(strategyId)" }
        return try await client.get(path, mock: MockRiskBFF.overview)
    }

    func getStopProtection() async throws -> StopProtectionBFFResponse {
        try await client.get("/api/risk/stop-protection", mock: MockRiskBFF.stopProtection)
    }

    func getCircuitBreakers() async throws -> CircuitBreakersBFFResponse {
        try await client.get("/api/risk/circuit-breakers", mock: MockRiskBFF.circuitBreakers)
    }

    func emergencyStop() async throws -> [String: String] {
        try await client.get("/api/risk/emergency-stop", mock: { ["status": "executed"] })
    }
}

// MARK: - Mock Data

enum MockRiskBFF {
    static func overview() -> RiskOverviewBFFResponse {
        RiskOverviewBFFResponse(
            state: "normal",
            availableActions: [
                AvailableActionResponse(type: "emergency_stop", enabled: true, label: "紧急停止", confirmRequired: true),
                AvailableActionResponse(type: "block_new_entries", enabled: true, label: "禁止新开仓"),
            ],
            guards: [
                RiskGuardResponse(key: "daily_loss", label: "日亏损限制", currentValue: 120, limitValue: 500, remainingPct: 0.76, status: "healthy"),
                RiskGuardResponse(key: "weekly_loss", label: "周亏损限制", currentValue: 280, limitValue: 1500, remainingPct: 0.81, status: "healthy"),
                RiskGuardResponse(key: "consecutive_loss", label: "连续亏损", currentValue: 1, limitValue: 5, remainingPct: 0.8, status: "healthy"),
            ]
        )
    }

    static func stopProtection() -> StopProtectionBFFResponse {
        StopProtectionBFFResponse(
            state: "healthy",
            availableActions: [AvailableActionResponse(type: "refresh_all", enabled: true, label: "刷新全部止损")],
            positions: [
                PositionStopResponse(positionId: "pos-001", symbol: "BTC/USDT", side: "long", entryPrice: 62100, currentPrice: 62450,
                    stops: StopLevelResponse(rawStructureStop: 61200, lastKnownGoodStop: 61350, secureRuntimeStop: 61350, exchangeProtectiveStop: 61000),
                    reasonCodes: ["structure_stop_valid"]),
                PositionStopResponse(positionId: "pos-002", symbol: "ETH/USDT", side: "long", entryPrice: 3380, currentPrice: 3410,
                    stops: StopLevelResponse(rawStructureStop: 3300, lastKnownGoodStop: 3320, secureRuntimeStop: 3320, exchangeProtectiveStop: 3280),
                    reasonCodes: ["structure_stop_valid"]),
            ]
        )
    }

    static func circuitBreakers() -> CircuitBreakersBFFResponse {
        CircuitBreakersBFFResponse(
            records: [
                CircuitBreakerRecordResponse(id: "cb-001", type: "daily_loss_lock", reasonCodes: ["daily_loss_limit_reached"]),
                CircuitBreakerRecordResponse(id: "cb-002", type: "emergency_stop", reasonCodes: ["manual_trigger"], relatedCommandId: "cmd-099"),
            ],
            totalCount: 2
        )
    }
}
