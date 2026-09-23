// APIRiskBFF.swift — Risk BFF API

import Foundation

// MARK: - Response Types

struct BlockActionResponse: Codable {
    let status: String
    let activeLocks: [ActiveLockResponse]

    enum CodingKeys: String, CodingKey {
        case status
        case activeLocks = "active_locks"
    }
}

struct ActiveLockResponse: Codable {
    let lock: String
    let reason: String?
}

struct RiskRulesResponse: Codable {
    let dailyLossLimit: Double
    let weeklyLossLimit: Double
    let consecutiveLossesLimit: Int
    let maxDrawdown: Double
    let correlationThreshold: Double
    let killSwitch: KillSwitchResponse

    enum CodingKeys: String, CodingKey {
        case dailyLossLimit = "daily_loss_limit"
        case weeklyLossLimit = "weekly_loss_limit"
        case consecutiveLossesLimit = "consecutive_losses_limit"
        case maxDrawdown = "max_drawdown"
        case correlationThreshold = "correlation_threshold"
        case killSwitch = "kill_switch"
    }
}

struct KillSwitchResponse: Codable {
    let threshold: Double
    let active: Bool
}


struct RiskRulesUpdateBody: Encodable {
    let dailyLossLimit: Double?
    let weeklyLossLimit: Double?
    let consecutiveLossesLimit: Int?
    let maxDrawdown: Double?
    let correlationThreshold: Double?
    let killSwitchActive: Bool?

    enum CodingKeys: String, CodingKey {
        case dailyLossLimit = "daily_loss_limit"
        case weeklyLossLimit = "weekly_loss_limit"
        case consecutiveLossesLimit = "consecutive_losses_limit"
        case maxDrawdown = "max_drawdown"
        case correlationThreshold = "correlation_threshold"
        case killSwitchActive = "kill_switch_active"
    }
}
struct ResolveCircuitBreakerResponse: Codable {
    let status: String
    let resolvedEventId: String?

    enum CodingKeys: String, CodingKey {
        case status
        case resolvedEventId = "resolved_event_id"
    }
}

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
    var resolved: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, type
        case accountId = "account_id"
        case strategyId = "strategy_id"
        case reasonCodes = "reason_codes"
        case relatedCommandId = "related_command_id"
        case relatedReconciliationId = "related_reconciliation_id"
        case createdAt = "created_at"
        case resolved
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
        return try await client.get(path)
    }

    func getStopProtection() async throws -> StopProtectionBFFResponse {
        try await client.get("/api/risk/stop-protection")
    }

    func getCircuitBreakers() async throws -> CircuitBreakersBFFResponse {
        try await client.get("/api/risk/circuit-breakers")
    }

    // MARK: - Block / Unblock New Entries

    func blockNewEntries(reason: String = "manual") async throws -> BlockActionResponse {
        try await client.post("/api/risk/block-new-entries", body: ["reason": reason])
    }

    func unblock() async throws -> BlockActionResponse {
        try await client.post("/api/risk/unblock", body: [String: String]())
    }

    // MARK: - Risk Rules

    func getRiskRules() async throws -> RiskRulesResponse {
        try await client.get("/api/risk/rules")
    }

    func updateRiskRules(body: RiskRulesUpdateBody) async throws -> RiskRulesResponse {
        try await client.put("/api/risk/rules", body: body)
    }

    // MARK: - Circuit Breaker

    func resolveCircuitBreaker(eventId: String) async throws -> ResolveCircuitBreakerResponse {
        try await client.post("/api/risk/circuit-breakers/\(eventId)/resolve", body: [String: String]())
    }

    // MARK: - Emergency Stop (delegates to APIEmergency)

    func emergencyStop() async throws -> EmergencyStopResult {
        let api = APIEmergency(client: client)
        return try await api.emergencyStop(reason: "manual")
    }

    // MARK: - Stop Protection actions

    func refreshStopProtection(positionId: String) async throws -> [String: AnyCodable] {
        try await client.post("/api/risk/stop-protection/\(positionId)/refresh", body: nil)
    }

    func forceLockPosition(positionId: String) async throws -> [String: AnyCodable] {
        try await client.post("/api/risk/stop-protection/\(positionId)/force-lock", body: nil)
    }

    func releaseLockPosition(positionId: String) async throws -> [String: AnyCodable] {
        try await client.post("/api/risk/stop-protection/\(positionId)/release-lock", body: nil)
    }

    func getExchangeProtectiveStops() async throws -> [String: AnyCodable] {
        try await client.get("/api/risk/exchange-protective-stops")
    }
}

