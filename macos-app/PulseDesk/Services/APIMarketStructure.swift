// APIMarketStructure.swift — Market Structure BFF API

import Foundation

// MARK: - Response Types

struct StructureZoneResponse: Codable, Identifiable {
    var id: String { zoneId }
    let zoneId: String
    let zoneType: String
    let direction: String
    var timeframe: String = "1h"
    var priceTop: Double = 0
    var priceBottom: Double = 0
    var status: String = "active"
    var currentStrength: Double = 0
    var filledRatio: Double = 0
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case zoneType = "zone_type"
        case zoneId = "zone_id"
        case direction, timeframe, status
        case priceTop = "price_top"
        case priceBottom = "price_bottom"
        case currentStrength = "current_strength"
        case filledRatio = "filled_ratio"
        case reasonCodes = "reason_codes"
    }
}

struct LiquidityPoolBFFResponse: Codable, Identifiable {
    var id: String { poolId }
    let poolId: String
    let poolType: String
    let side: String
    var priceLevel: Double = 0
    var currentStrength: Double = 0
    var status: String = "active"
    var touchedCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case poolId = "pool_id"
        case poolType = "pool_type"
        case side, status
        case priceLevel = "price_level"
        case currentStrength = "current_strength"
        case touchedCount = "touched_count"
    }
}

struct StructureEventResponse: Codable, Identifiable {
    var id: String { eventId }
    let eventId: String
    let eventType: String
    var direction: String = ""
    var price: Double = 0
    var timeframe: String = ""
    var timestamp: String = ""

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventType = "event_type"
        case direction, price, timeframe, timestamp
    }
}

struct MarketStructureBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var symbol: String = ""
    var timeframe: String = "5m"
    var marketRegime: String = "unknown"
    var structureScore: Double = 0
    var zones: [StructureZoneResponse] = []
    var liquidityPools: [LiquidityPoolBFFResponse] = []
    var events: [StructureEventResponse] = []
    var premiumDiscount: String = ""

    enum CodingKeys: String, CodingKey {
        case state, symbol, timeframe, zones, events
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case marketRegime = "market_regime"
        case structureScore = "structure_score"
        case liquidityPools = "liquidity_pools"
        case premiumDiscount = "premium_discount"
    }
}

// MARK: - API Service

struct APIMarketStructure {
    let client: NetworkClientProtocol

    func getMarketView(symbol: String = "BTC/USDT", timeframe: String = "5m") async throws -> MarketStructureBFFResponse {
        try await client.get("/api/structure/market-view?symbol=\(symbol)&timeframe=\(timeframe)", mock: MockMarketStructure.marketView)
    }

    func getZones(symbol: String = "BTC/USDT") async throws -> MarketStructureBFFResponse {
        try await client.get("/api/structure/zones?symbol=\(symbol)", mock: MockMarketStructure.marketView)
    }
}

// MARK: - Mock

enum MockMarketStructure {
    static func marketView() -> MarketStructureBFFResponse {
        MarketStructureBFFResponse(
            state: "healthy",
            reasonCodes: [],
            availableActions: [
                AvailableActionResponse(type: "refresh_structure", enabled: true, label: "刷新结构数据"),
            ],
            symbol: "BTC/USDT",
            timeframe: "5m",
            marketRegime: "trend_up",
            structureScore: 76,
            zones: [
                StructureZoneResponse(zoneId: "fvg-001", zoneType: "fvg", direction: "bullish", timeframe: "1h", priceTop: 62000, priceBottom: 61550, status: "active", currentStrength: 0.82, filledRatio: 0.21),
                StructureZoneResponse(zoneId: "fvg-002", zoneType: "fvg", direction: "bearish", timeframe: "4h", priceTop: 63200, priceBottom: 63050, status: "active", currentStrength: 0.68, filledRatio: 0.05),
                StructureZoneResponse(zoneId: "ob-001", zoneType: "order_block", direction: "bullish", timeframe: "1h", priceTop: 61800, priceBottom: 61500, status: "active", currentStrength: 0.91),
                StructureZoneResponse(zoneId: "lp-001", zoneType: "liquidity_pool", direction: "bearish", timeframe: "4h", priceTop: 60200, priceBottom: 60200, status: "active", currentStrength: 0.75),
            ],
            liquidityPools: [
                LiquidityPoolBFFResponse(poolId: "pool-001", poolType: "equal_low", side: "sell_side", priceLevel: 60200, currentStrength: 0.85, status: "active", touchedCount: 2),
                LiquidityPoolBFFResponse(poolId: "pool-002", poolType: "swing_high", side: "buy_side", priceLevel: 63500, currentStrength: 0.72, status: "active", touchedCount: 0),
                LiquidityPoolBFFResponse(poolId: "pool-003", poolType: "equal_high", side: "buy_side", priceLevel: 64100, currentStrength: 0.68, status: "touched", touchedCount: 1),
            ],
            events: [
                StructureEventResponse(eventId: "evt-001", eventType: "bos", direction: "bullish", price: 62100, timeframe: "1h", timestamp: "2026-06-05T14:30:00Z"),
                StructureEventResponse(eventId: "evt-002", eventType: "sweep", direction: "bearish", price: 60200, timeframe: "4h", timestamp: "2026-06-05T12:00:00Z"),
                StructureEventResponse(eventId: "evt-003", eventType: "fvg_fill", direction: "bullish", price: 61600, timeframe: "1h", timestamp: "2026-06-05T15:00:00Z"),
            ],
            premiumDiscount: "premium"
        )
    }
}
