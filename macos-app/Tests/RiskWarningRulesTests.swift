// RiskWarningRulesTests.swift — Tests for riskWarnings pure function
// TDD: 5 tests covering thresholds, sorting, and cardinality

import Testing
import Foundation
@testable import AlphaLoop

@Suite("RiskWarningRules Tests")
struct RiskWarningRulesTests {

    @Test func maxDrawdownBeyond25TriggersRed() {
        let m = BacktestMetrics(totalReturn: 0.1, sharpeRatio: 1.5, maxDrawdown: -0.30,
                                winRate: 0.55, profitFactor: 1.6, totalTrades: 100,
                                avgTradeDuration: "1h", bestTrade: 0.05, worstTrade: -0.03)
        let ws = riskWarnings(for: m)
        #expect(ws.contains { $0.level == .red && $0.id == "max_drawdown" })
    }

    @Test func lowTradesTriggersYellow() {
        let m = BacktestMetrics(totalReturn: 0.1, sharpeRatio: 1.5, maxDrawdown: -0.05,
                                winRate: 0.55, profitFactor: 1.6, totalTrades: 20,
                                avgTradeDuration: "1h", bestTrade: 0.05, worstTrade: -0.03)
        let ws = riskWarnings(for: m)
        #expect(ws.contains { $0.level == .yellow && $0.id == "low_trades" })
    }

    @Test func noWarningsForHealthyMetrics() {
        let m = BacktestMetrics(totalReturn: 0.2, sharpeRatio: 2.0, maxDrawdown: -0.10,
                                winRate: 0.55, profitFactor: 1.8, totalTrades: 200,
                                avgTradeDuration: "1h", bestTrade: 0.05, worstTrade: -0.02)
        #expect(riskWarnings(for: m) == [])
    }

    @Test func warningsSortedBySeverity() {
        let m = BacktestMetrics(totalReturn: -0.1, sharpeRatio: -0.5, maxDrawdown: -0.30,
                                winRate: 0.30, profitFactor: 0.8, totalTrades: 20,
                                avgTradeDuration: "1h", bestTrade: 0.01, worstTrade: -0.05)
        let ws = riskWarnings(for: m)
        #expect(ws.first?.level == .red)
    }

    @Test func atMost5Warnings() {
        let m = BacktestMetrics(totalReturn: -0.1, sharpeRatio: -0.5, maxDrawdown: -0.30,
                                winRate: 0.30, profitFactor: 0.8, totalTrades: 10,
                                avgTradeDuration: "1h", bestTrade: 0.01, worstTrade: -0.05)
        let ws = riskWarnings(for: m)
        #expect(ws.count <= 5)
    }
}
