// APIStructureBFF.swift — Structure BFF API

import Foundation

// MARK: - Matrix Types

struct MatrixCellResponse: Codable {
    var zoneType: String = ""
    var status: String = "unknown"
    var currentStrength: Double = 0
    var filledRatio: Double = 0
    var temporaryViolation: Bool = false
    var action: String = ""
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case status, action
        case zoneType = "zone_type"
        case currentStrength = "current_strength"
        case filledRatio = "filled_ratio"
        case temporaryViolation = "temporary_violation"
        case reasonCodes = "reason_codes"
    }
}

struct MatrixRowResponse: Codable {
    let timeframe: String
    var cells: [String: MatrixCellResponse] = [:]
}

struct StructureMatrixBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var symbol: String = ""
    var baseTimeframe: String = "5m"
    var rows: [MatrixRowResponse] = []

    enum CodingKeys: String, CodingKey {
        case state, symbol, rows
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case baseTimeframe = "base_timeframe"
    }
}

// MARK: - Shadow Window Types

struct ShadowWindowResponse: Codable, Identifiable {
    var id: String { "\(timeframe)-\(zoneType)" }
    var timeframe: String = ""
    var zoneType: String = ""
    var status: String = "active"   // active / violation / reclaim / expired / closed
    var violationType: String? = nil
    var reasonCodes: [String] = []
    // Derived/optional richer fields (will be empty when backend hasn't computed them)
    var fastTimeframe: String? = nil
    var slowTimeframe: String? = nil
    var direction: String? = nil
    var fastCandleCount: Int = 0
    var fastCandleMax: Int = 12
    var filledRatio: Double = 0
    var violationCount: Int = 0
    var reclaimCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case timeframe, status, direction
        case zoneType = "zone_type"
        case violationType = "violation_type"
        case reasonCodes = "reason_codes"
        case fastTimeframe = "fast_timeframe"
        case slowTimeframe = "slow_timeframe"
        case fastCandleCount = "fast_candle_count"
        case fastCandleMax = "fast_candle_max"
        case filledRatio = "filled_ratio"
        case violationCount = "violation_count"
        case reclaimCount = "reclaim_count"
    }
}

struct ShadowWindowsBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var symbol: String = ""
    var windows: [ShadowWindowResponse] = []

    enum CodingKeys: String, CodingKey {
        case state, symbol, windows
        case reasonCodes = "reason_codes"
    }
}

// MARK: - MTF Guard Types

struct MTFGuardViolation: Codable {
    var fastTimeframe: String? = nil
    var slowTimeframe: String? = nil
    var zoneType: String? = nil
    var direction: String? = nil
    var startedAt: String? = nil
    var htfCloseAt: String? = nil           // ISO timestamp of next HTF close
    var countdownSeconds: Int? = nil        // seconds until HTF close

    enum CodingKeys: String, CodingKey {
        case direction
        case fastTimeframe = "fast_timeframe"
        case slowTimeframe = "slow_timeframe"
        case zoneType = "zone_type"
        case startedAt = "started_at"
        case htfCloseAt = "htf_close_at"
        case countdownSeconds = "countdown_seconds"
    }
}

struct MTFGuardResponse: Codable {
    var strategyId: String = ""
    var symbol: String = ""
    var guardState: String = "inactive"   // inactive/watching/pending_htf_close/temporary_violation/reclaim_pending/confirmed/invalidated/expired
    var action: String = "ignore"
    var reasonCodes: [String] = []
    var violation: MTFGuardViolation = MTFGuardViolation()

    enum CodingKeys: String, CodingKey {
        case symbol, action, violation
        case strategyId = "strategy_id"
        case guardState = "guard_state"
        case reasonCodes = "reason_codes"
    }
}

struct MTFGuardEventResponse: Codable, Identifiable {
    var id: String = ""
    var strategyId: String = ""
    var symbol: String = ""
    var fastTimeframe: String = ""
    var slowTimeframe: String = ""
    var structureType: String = ""
    var guardState: String = ""
    var action: String = ""
    var htfCandleClosed: Bool = false
    var reasonCodes: [String] = []
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol, action
        case strategyId = "strategy_id"
        case fastTimeframe = "fast_timeframe"
        case slowTimeframe = "slow_timeframe"
        case structureType = "structure_type"
        case guardState = "guard_state"
        case htfCandleClosed = "htf_candle_closed"
        case reasonCodes = "reason_codes"
        case createdAt = "created_at"
    }
}

struct MTFGuardEventsResponse: Codable {
    var strategyId: String = ""
    var events: [MTFGuardEventResponse] = []
    var total: Int = 0

    enum CodingKeys: String, CodingKey {
        case events, total
        case strategyId = "strategy_id"
    }
}

// MARK: - Fast Track Health

struct FastTrackHealthResponse: Codable {
    var latencyMs: Int = 0
    var dataAgeSeconds: Double = 0
    var redisOk: Bool = true
    var verdictTrustworthy: Bool = true

    enum CodingKeys: String, CodingKey {
        case latencyMs = "latency_ms"
        case dataAgeSeconds = "data_age_seconds"
        case redisOk = "redis_ok"
        case verdictTrustworthy = "verdict_trustworthy"
    }
}

// MARK: - API Service

struct APIStructureBFF {
    let client: NetworkClientProtocol

    func getMatrix(symbol: String = "BTC/USDT") async throws -> StructureMatrixBFFResponse {
        try await client.get("/api/structure/matrix?symbol=\(symbol)")
    }

    func getShadowWindows(symbol: String = "BTC/USDT") async throws -> ShadowWindowsBFFResponse {
        try await client.get("/api/structure/shadow-windows?symbol=\(symbol)")
    }

    func getMTFGuard(strategyId: String = "default", symbol: String = "BTC/USDT") async throws -> MTFGuardResponse {
        try await client.get("/api/structure/mtf-guard/\(strategyId)/\(symbol)")
    }

    func getMTFGuardEvents(strategyId: String = "default", symbol: String = "BTC/USDT", limit: Int = 50) async throws -> MTFGuardEventsResponse {
        try await client.get("/api/structure/mtf-guard-events/\(strategyId)?symbol=\(symbol)&limit=\(limit)")
    }

    func getFastTrackHealth() async throws -> FastTrackHealthResponse {
        try await client.get("/api/system/fast-track-health")
    }
}

// MARK: - Mock

