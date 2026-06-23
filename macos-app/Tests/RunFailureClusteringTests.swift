// RunFailureClusteringTests.swift — Tests for clusterFailures pure function
// TDD: 4 tests covering cardinality, bucketing, profit filtering, and cluster limit

import Testing
import Foundation
@testable import AlphaLoop

@Suite("RunFailureClustering Tests")
struct RunFailureClusteringTests {

    private func trade(profit: Double, duration: String = "1h", pair: String = "BTC/USDT",
                       side: String = "long", openTime: String = "2024-01-01T00:00:00Z",
                       mtfState: String? = "confirmed") -> TradeRow {
        TradeRow(openTime: openTime, closeTime: openTime, pair: pair, side: side,
                 openPrice: 40000, closePrice: 40500, quantity: 0.1, profit: profit,
                 duration: duration, mtfState: mtfState)
    }

    @Test func returnsEmptyWhenFewerThan5Losses() {
        let trades = [
            trade(profit: -10), trade(profit: -10), trade(profit: -10), trade(profit: -10),
        ]
        #expect(clusterFailures(in: trades) == [])
    }

    @Test func clustersByDurationBucket() {
        let trades: [TradeRow] = [
            trade(profit: -10, duration: "0.5h"), trade(profit: -10, duration: "0.5h"),
            trade(profit: -10, duration: "0.5h"), trade(profit: -10, duration: "0.5h"),
            trade(profit: -10, duration: "0.5h"),
            trade(profit: -10, duration: "24h"), trade(profit: -10, duration: "24h"),
            trade(profit: -10, duration: "24h"), trade(profit: -10, duration: "24h"),
            trade(profit: -10, duration: "24h"),
        ]
        let clusters = clusterFailures(in: trades)
        #expect(clusters.count == 2)
    }

    @Test func ignoresProfitableTrades() {
        let trades: [TradeRow] = [
            trade(profit: 100), trade(profit: 100), trade(profit: 100),
            trade(profit: -10), trade(profit: -10), trade(profit: -10),
            trade(profit: -10), trade(profit: -10),
        ]
        let clusters = clusterFailures(in: trades)
        #expect(clusters.count == 1)
        #expect(clusters[0].sampleSize == 5)
    }

    @Test func atMost5Clusters() {
        var trades: [TradeRow] = []
        for bucket in ["0.5h", "1h", "2h", "4h", "12h", "24h", "48h"] {
            for _ in 0..<5 {
                trades.append(trade(profit: -10, duration: bucket))
            }
        }
        let clusters = clusterFailures(in: trades)
        #expect(clusters.count <= 5)
    }
}
