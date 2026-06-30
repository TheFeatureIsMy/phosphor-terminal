// MockBacktest.swift — Centralized mock factories for backtest responses.
// Honest data: flat equity curve, modest metrics — never get-rich patterns.

import Foundation

enum MockBacktest {
    static func commandResponse() -> BacktestCommandResponseV2 {
        BacktestCommandResponseV2(
            commandId: UUID().uuidString,
            status: "pending",
            message: "Backtest enqueued (mock)",
            idempotencyKey: UUID().uuidString
        )
    }

    static func status(commandId: String, runId: Int = 1) -> BacktestStatusV2 {
        BacktestStatusV2(
            commandId: commandId,
            commandStatus: "completed",
            backtestRun: run(id: runId),
            errorCode: nil,
            errorMessage: nil
        )
    }

    static func run(id: Int) -> BacktestRunV2 {
        // Flat, modest equity curve — 4 points, ~0.3% total return
        let equityCurve = [
            BacktestEquityPoint(timestamp: "2026-01-01", equity: 10000.0, drawdown: 0.0),
            BacktestEquityPoint(timestamp: "2026-01-08", equity: 10015.0, drawdown: -8.0),
            BacktestEquityPoint(timestamp: "2026-01-15", equity: 10022.0, drawdown: -3.0),
            BacktestEquityPoint(timestamp: "2026-01-22", equity: 10030.0, drawdown: 0.0),
        ]
        let trades = [
            TradeRow(openTime: "2026-01-01 00:00", closeTime: "2026-01-03 12:00",
                     pair: "BTC/USDT", side: "long", openPrice: 40000, closePrice: 40200,
                     quantity: 0.025, profit: 5.0, duration: "2d 12h", mtfState: nil),
            TradeRow(openTime: "2026-01-08 04:00", closeTime: "2026-01-09 06:00",
                     pair: "ETH/USDT", side: "long", openPrice: 3000, closePrice: 2990,
                     quantity: 0.5, profit: -5.0, duration: "1d 2h", mtfState: nil),
            TradeRow(openTime: "2026-01-15 08:00", closeTime: "2026-01-16 10:00",
                     pair: "BTC/USDT", side: "long", openPrice: 40100, closePrice: 40350,
                     quantity: 0.025, profit: 6.25, duration: "1d 2h", mtfState: nil),
        ]
        return BacktestRunV2(
            id: id, strategyId: 1, strategyVersionId: "v1", commandId: UUID().uuidString,
            dslHash: "a1b2c3d4", status: "completed",
            startDate: "2026-01-01", endDate: "2026-01-22",
            initialCapital: 10000.0, symbols: ["BTC/USDT", "ETH/USDT"],
            config: [:], result: [:],
            sharpeRatio: 0.42, maxDrawdown: 0.08, winRate: 0.66,
            totalReturn: 0.30, profitFactor: 1.6, totalTrades: 3,
            errorMessage: nil,
            createdAt: "2026-06-30T00:00:00Z", completedAt: "2026-06-30T00:01:00Z",
            equityCurve: equityCurve, trades: trades
        )
    }
}
