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
        try await client.get("/api/structure/matrix?symbol=\(symbol)", mock: MockStructureBFF.matrix)
    }

    func getShadowWindows(symbol: String = "BTC/USDT") async throws -> ShadowWindowsBFFResponse {
        try await client.get("/api/structure/shadow-windows?symbol=\(symbol)", mock: { MockStructureBFF.shadowWindows(symbol: symbol) })
    }

    func getMTFGuard(strategyId: String = "default", symbol: String = "BTC/USDT") async throws -> MTFGuardResponse {
        try await client.get("/api/structure/mtf-guard/\(strategyId)/\(symbol)", mock: { MockStructureBFF.mtfGuard(strategyId: strategyId, symbol: symbol) })
    }

    func getMTFGuardEvents(strategyId: String = "default", symbol: String = "BTC/USDT", limit: Int = 50) async throws -> MTFGuardEventsResponse {
        try await client.get("/api/structure/mtf-guard-events/\(strategyId)?symbol=\(symbol)&limit=\(limit)", mock: { MockStructureBFF.mtfGuardEvents(strategyId: strategyId, symbol: symbol) })
    }

    func getFastTrackHealth() async throws -> FastTrackHealthResponse {
        try await client.get("/api/system/fast-track-health", mock: MockStructureBFF.fastTrackHealth)
    }
}

// MARK: - Mock

enum MockStructureBFF {
    static func matrix() -> StructureMatrixBFFResponse {
        StructureMatrixBFFResponse(
            state: "warning",
            reasonCodes: ["1h_bullish_ob_violation"],
            availableActions: [AvailableActionResponse(type: "refresh_structure", enabled: true, label: "刷新结构数据")],
            symbol: "BTC/USDT",
            rows: [
                MatrixRowResponse(timeframe: "5m", cells: [
                    "order_block": MatrixCellResponse(zoneType: "order_block", status: "active", currentStrength: 0.78, action: "allow"),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.65, filledRatio: 0.35, action: "allow"),
                    "liquidity_pool": MatrixCellResponse(zoneType: "liquidity_pool", status: "active", currentStrength: 0.42, action: "allow"),
                ]),
                MatrixRowResponse(timeframe: "15m", cells: [
                    "order_block": MatrixCellResponse(zoneType: "order_block", status: "active", currentStrength: 0.22, action: "allow"),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.48, filledRatio: 0.42, action: "allow"),
                    "liquidity_pool": MatrixCellResponse(zoneType: "liquidity_pool", status: "active", currentStrength: 0.38, action: "allow"),
                ]),
                MatrixRowResponse(timeframe: "1h", cells: [
                    "order_block": MatrixCellResponse(zoneType: "order_block", status: "warning", currentStrength: 0.18, temporaryViolation: true, action: "reduce_size", reasonCodes: ["shadow_low_violated_ob_bottom"]),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.50, filledRatio: 0.85, action: "reduce_size"),
                    "liquidity_pool": MatrixCellResponse(zoneType: "liquidity_pool", status: "active", currentStrength: 0.71, action: "allow"),
                ]),
                MatrixRowResponse(timeframe: "4h", cells: [
                    "order_block": MatrixCellResponse(zoneType: "order_block", status: "active", currentStrength: 0.64, action: "allow"),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.18, filledRatio: 0.12, action: "allow"),
                    "liquidity_pool": MatrixCellResponse(zoneType: "liquidity_pool", status: "active", currentStrength: 0.31, action: "allow"),
                ]),
            ]
        )
    }

    static func shadowWindows(symbol: String) -> ShadowWindowsBFFResponse {
        ShadowWindowsBFFResponse(
            state: "warning",
            reasonCodes: ["1h_shadow_temporary_violation"],
            symbol: symbol,
            windows: [
                ShadowWindowResponse(
                    timeframe: "1h",
                    zoneType: "order_block",
                    status: "violation",
                    violationType: "temporary",
                    reasonCodes: ["fast_tf_below_zone_bottom"],
                    fastTimeframe: "15m",
                    slowTimeframe: "1h",
                    direction: "short",
                    fastCandleCount: 8,
                    fastCandleMax: 12,
                    filledRatio: 0.34,
                    violationCount: 2,
                    reclaimCount: 0
                ),
                ShadowWindowResponse(
                    timeframe: "15m",
                    zoneType: "fvg",
                    status: "active",
                    violationType: nil,
                    reasonCodes: ["shadow_intact"],
                    fastTimeframe: "5m",
                    slowTimeframe: "15m",
                    direction: "long",
                    fastCandleCount: 11,
                    fastCandleMax: 12,
                    filledRatio: 0.42,
                    violationCount: 0,
                    reclaimCount: 1
                ),
            ]
        )
    }

    static func mtfGuard(strategyId: String, symbol: String) -> MTFGuardResponse {
        MTFGuardResponse(
            strategyId: strategyId,
            symbol: symbol,
            guardState: "temporary_violation",
            action: "reduce_size",
            reasonCodes: ["1h_ob_bottom_pierced"],
            violation: MTFGuardViolation(
                fastTimeframe: "15m",
                slowTimeframe: "1h",
                zoneType: "order_block",
                direction: "short",
                startedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-900)),
                htfCloseAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(2531)),
                countdownSeconds: 2531
            )
        )
    }

    static func mtfGuardEvents(strategyId: String, symbol: String) -> MTFGuardEventsResponse {
        let now = Date()
        let iso = ISO8601DateFormatter()
        return MTFGuardEventsResponse(
            strategyId: strategyId,
            events: [
                MTFGuardEventResponse(
                    id: "evt_001",
                    strategyId: strategyId,
                    symbol: symbol,
                    fastTimeframe: "5m",
                    slowTimeframe: "1h",
                    structureType: "order_block",
                    guardState: "temporary_violation",
                    action: "block_entry",
                    htfCandleClosed: false,
                    reasonCodes: ["fast_tf_entered_htf_zone"],
                    createdAt: iso.string(from: now.addingTimeInterval(-180))
                ),
                MTFGuardEventResponse(
                    id: "evt_002",
                    strategyId: strategyId,
                    symbol: symbol,
                    fastTimeframe: "5m",
                    slowTimeframe: "1h",
                    structureType: "fvg",
                    guardState: "confirmed",
                    action: "allow",
                    htfCandleClosed: true,
                    reasonCodes: ["htf_close_reclaimed"],
                    createdAt: iso.string(from: now.addingTimeInterval(-3600))
                ),
                MTFGuardEventResponse(
                    id: "evt_003",
                    strategyId: strategyId,
                    symbol: symbol,
                    fastTimeframe: "15m",
                    slowTimeframe: "4h",
                    structureType: "liquidity_pool",
                    guardState: "watching",
                    action: "observe",
                    htfCandleClosed: false,
                    reasonCodes: ["approaching_liquidity"],
                    createdAt: iso.string(from: now.addingTimeInterval(-7200))
                ),
            ],
            total: 3
        )
    }

    static func fastTrackHealth() -> FastTrackHealthResponse {
        FastTrackHealthResponse(
            latencyMs: 45,
            dataAgeSeconds: 1.2,
            redisOk: true,
            verdictTrustworthy: true
        )
    }
}
