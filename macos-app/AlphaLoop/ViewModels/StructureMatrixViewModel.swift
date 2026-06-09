// StructureMatrixViewModel.swift — 结构矩阵 ViewModel (HTF Tribunal)

import SwiftUI

@Observable
@MainActor
final class StructureMatrixViewModel {
    var matrixData: StructureMatrixBFFResponse?
    var shadowWindows: ShadowWindowsBFFResponse?
    var mtfGuard: MTFGuardResponse?
    var guardEvents: MTFGuardEventsResponse?
    var fastTrackHealth: FastTrackHealthResponse?

    var selectedSymbol = "BTC/USDT"
    var selectedTimeframe: String = "1h"
    var strategyId: String = "default"
    var isLoading = false
    var error: String?

    /// Drives the HTF countdown ring. Updated by a 1Hz timer in the view.
    var countdownSeconds: Int = 0

    private let api: APIStructureBFF

    init(client: NetworkClientProtocol) {
        self.api = APIStructureBFF(client: client)
    }

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        async let m = api.getMatrix(symbol: selectedSymbol)
        async let s = api.getShadowWindows(symbol: selectedSymbol)
        async let g = api.getMTFGuard(strategyId: strategyId, symbol: selectedSymbol)
        async let e = api.getMTFGuardEvents(strategyId: strategyId, symbol: selectedSymbol)
        async let h = api.getFastTrackHealth()

        do {
            let (matrix, shadows, guard_, events, health) = try await (m, s, g, e, h)
            self.matrixData = matrix
            self.shadowWindows = shadows
            self.mtfGuard = guard_
            self.guardEvents = events
            self.fastTrackHealth = health
            self.countdownSeconds = guard_.violation.countdownSeconds ?? 0
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Back-compat alias kept for existing call sites.
    func loadMatrix() async { await loadAll() }

    func refresh() async {
        await loadAll()
    }

    func tickCountdown() {
        if countdownSeconds > 0 { countdownSeconds -= 1 }
    }
}
