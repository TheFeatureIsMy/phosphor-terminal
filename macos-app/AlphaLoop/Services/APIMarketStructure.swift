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
        try await client.get("/api/structure/market-view?symbol=\(symbol)&timeframe=\(timeframe)")
    }

    func getZones(symbol: String = "BTC/USDT") async throws -> MarketStructureBFFResponse {
        try await client.get("/api/structure/zones?symbol=\(symbol)")
    }
}

// MARK: - Mock

