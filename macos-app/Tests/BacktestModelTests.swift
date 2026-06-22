// BacktestModelTests.swift — Tests for BacktestEquityPoint, TradeRow, FailureClusterSummary
// and BacktestRunV2 equityCurve/trades extraction from result

import Testing
import Foundation
@testable import AlphaLoop

@Suite("Backtest Model Tests")
struct BacktestModelTests {

    @Test func equityPointDecodes() throws {
        let json = #"{"timestamp":"2024-01-01","equity":10000.0,"drawdown":0.0}"#
        let pt = try JSONDecoder().decode(BacktestEquityPoint.self, from: json.data(using: .utf8)!)
        #expect(pt.equity == 10000.0)
    }

    @Test func tradeRowDecodes() throws {
        let json = #"{"open_time":"2024-01-01","close_time":"2024-01-01","pair":"BTC/USDT","side":"long","open_price":40000.0,"close_price":40500.0,"quantity":0.1,"profit":50.0,"duration":"1h","mtf_state":"confirmed"}"#
        let t = try JSONDecoder().decode(TradeRow.self, from: json.data(using: .utf8)!)
        #expect(t.pair == "BTC/USDT")
        #expect(t.profit == 50.0)
    }

    @Test func backtestRunV2ExtractsEquityCurveFromResult() throws {
        let json = """
        {"id":1,"strategy_id":1,"status":"completed","start_date":"20240101","end_date":"20240601","initial_capital":10000.0,
         "result":{"equity_curve":[{"timestamp":"2024-01-01","equity":10000.0,"drawdown":0.0}],
                   "trades":[{"open_time":"2024-01-01","close_time":"2024-01-01","pair":"BTC/USDT","side":"long","open_price":40000.0,"close_price":40500.0,"quantity":0.1,"profit":50.0,"duration":"1h"}]}}
        """
        let run = try JSONDecoder().decode(BacktestRunV2.self, from: json.data(using: .utf8)!)
        #expect(run.equityCurve.count == 1)
        #expect(run.trades.count == 1)
    }
}
