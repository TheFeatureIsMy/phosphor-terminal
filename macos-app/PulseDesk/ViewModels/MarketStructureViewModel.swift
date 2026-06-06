// MarketStructureViewModel.swift — 市场结构 ViewModel

import SwiftUI

@Observable
@MainActor
final class MarketStructureViewModel {
    var data: MarketStructureBFFResponse?
    var selectedSymbol = "BTC/USDT"
    var selectedTimeframe = "5m"
    var isLoading = false
    var error: String?
    var selectedZone: StructureZoneResponse?

    private let api: APIMarketStructure

    init(client: any NetworkClientProtocol) {
        self.api = APIMarketStructure(client: client)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            data = try await api.getMarketView(symbol: selectedSymbol, timeframe: selectedTimeframe)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }

    var zones: [StructureZoneResponse] { data?.zones ?? [] }
    var pools: [LiquidityPoolBFFResponse] { data?.liquidityPools ?? [] }
    var events: [StructureEventResponse] { data?.events ?? [] }
    var regime: String { data?.marketRegime ?? "unknown" }
    var score: Double { data?.structureScore ?? 0 }
    var premiumDiscount: String { data?.premiumDiscount ?? "" }
}
