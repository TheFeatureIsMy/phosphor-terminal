// APIBacktestV2Tests.swift — Tests for APIBacktestV2 service
// Verifies mock data returns for v2 backtest API methods

import Testing
import Foundation
@testable import AlphaLoop

@Suite("APIBacktestV2 Tests")
struct APIBacktestV2Tests {

    let client = MockNetworkClient()

    @Test func startBacktestBuildsRequest() async throws {
        let resp = try await client.startBacktestV2(
            dsl: ["version": AnyCodable("2.5")],
            timerange: "20240101-20240601",
            symbols: ["BTC/USDT"],
            initialCapital: 10000,
            slippageBps: 5.0
        )
        #expect(!resp.commandId.isEmpty)
    }

    @Test func getBacktestDecodesEquityCurve() async throws {
        let run = try await client.getBacktestV2(id: 1)
        #expect(run.status == "completed")
        #expect(!run.equityCurve.isEmpty)
    }
}
