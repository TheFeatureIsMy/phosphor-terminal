// APIStructureBFF.swift — Structure BFF API

import Foundation

// MARK: - Response Types

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

// MARK: - API Service

struct APIStructureBFF {
    let client: NetworkClientProtocol

    func getMatrix(symbol: String = "BTC/USDT") async throws -> StructureMatrixBFFResponse {
        try await client.get("/api/structure/matrix?symbol=\(symbol)", mock: MockStructureBFF.matrix)
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
                    "bullish_ob": MatrixCellResponse(zoneType: "order_block", status: "active", currentStrength: 0.78, action: "allow"),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.65, filledRatio: 0.35, action: "allow"),
                ]),
                MatrixRowResponse(timeframe: "1h", cells: [
                    "bullish_ob": MatrixCellResponse(zoneType: "order_block", status: "warning", currentStrength: 0.41, temporaryViolation: true, action: "reduce_size", reasonCodes: ["shadow_low_violated_ob_bottom"]),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.55, filledRatio: 0.85, action: "reduce_size"),
                ]),
                MatrixRowResponse(timeframe: "4h", cells: [
                    "bullish_ob": MatrixCellResponse(zoneType: "order_block", status: "active", currentStrength: 0.88, action: "allow"),
                    "fvg": MatrixCellResponse(zoneType: "fvg", status: "active", currentStrength: 0.92, filledRatio: 0.12, action: "allow"),
                ]),
            ]
        )
    }
}
