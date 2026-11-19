// PositionData.swift — dashboard position projection shared with ViewModels

import SwiftUI

struct PositionData: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let direction: String
    let size: Double
    let entryPrice: Double
    let currentPrice: Double
    let pnl: Double
    let pnlPct: Double
    let riskLevel: String
    let reasonCodes: [String]
    let stateDifference: String?

    var isLong: Bool { direction.lowercased() == "long" }

    var stateKey: String {
        switch (stateDifference ?? "").lowercased() {
        case "in_sync", "": return "in_sync"
        case "drift": return "drift"
        case "local_only": return "local_only"
        case "exchange_only": return "exchange_only"
        default: return "unknown"
        }
    }
}
