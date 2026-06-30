// APIStrategyRuns.swift — Strategy Run API (list runs, orders, ledger)

import Foundation

struct APIStrategyRuns {
    let client: NetworkClientProtocol

    func listRuns(
        mode: String? = nil,
        status: String? = nil,
        strategyId: String? = nil,
        strategyVersionId: String? = nil,
        limit: Int = 20
    ) async throws -> [StrategyRunV2] {
        var path = "/api/v2/strategy-runs?limit=\(limit)"
        if let mode { path += "&mode=\(mode)" }
        if let status { path += "&status=\(status)" }
        if let strategyId { path += "&strategy_id=\(strategyId)" }
        if let strategyVersionId { path += "&strategy_version_id=\(strategyVersionId)" }
        return try await client.get(path, mock: MockStrategyRuns.list)
    }

    func getRun(_ id: String) async throws -> StrategyRunV2 {
        try await client.get("/api/v2/strategy-runs/\(id)",
            mock: { MockStrategyRuns.detail(id: id) })
    }

    func getRunOrders(_ runId: String, limit: Int = 50) async throws -> [Order] {
        try await client.get("/api/v2/strategy-runs/\(runId)/orders?limit=\(limit)",
            mock: MockStrategyRuns.orders)
    }

    func getRunLedger(_ runId: String, limit: Int = 50) async throws -> [AnyCodable] {
        try await client.get("/api/v2/strategy-runs/\(runId)/ledger?limit=\(limit)",
            mock: { MockStrategyRuns.ledger(runId: runId) })
    }
}

enum MockStrategyRuns {
    static func list() -> [StrategyRunV2] {
        [
            detail(id: UUID().uuidString),
            StrategyRunV2(
                id: UUID().uuidString, strategyVersionId: UUID().uuidString,
                mode: "live", status: "stopped",
                startedAt: "2026-06-04T10:00:00Z", stoppedAt: "2026-06-05T06:00:00Z",
                createdAt: "2026-06-04T09:50:00Z",
                configSnapshot: AnyCodable(["symbol": "ETH/USDT", "exchange": "binance", "stake_amount": 50]),
                resultSummary: AnyCodable(["total_trades": 8, "win_rate": 0.50, "total_pnl": -52.30])
            ),
            StrategyRunV2(
                id: UUID().uuidString, strategyVersionId: UUID().uuidString,
                mode: "dryrun", status: "error",
                startedAt: "2026-06-03T14:00:00Z", stoppedAt: "2026-06-03T14:05:00Z",
                createdAt: "2026-06-03T13:55:00Z",
                configSnapshot: AnyCodable(["symbol": "SOL/USDT", "exchange": "binance"]),
                resultSummary: nil
            ),
        ]
    }

    static func detail(id: String) -> StrategyRunV2 {
        StrategyRunV2(
            id: id, strategyVersionId: UUID().uuidString,
            mode: "dryrun", status: "running",
            startedAt: "2026-06-05T08:00:00Z", stoppedAt: nil,
            createdAt: "2026-06-05T07:55:00Z",
            configSnapshot: AnyCodable(["symbol": "BTC/USDT", "exchange": "binance", "stake_amount": 100]),
            resultSummary: AnyCodable(["total_trades": 12, "win_rate": 0.67, "total_pnl": 245.80, "sharpe_ratio": 1.45])
        )
    }

    static func orders() -> [Order] {
        [
            Order(id: 1001, strategyId: 1, symbol: "BTC/USDT", side: .buy,
                orderType: .limit, quantity: 0.015, price: 68420.50,
                filledPrice: 68418.20, fee: 1.03, slippage: 0.003,
                timestamp: "2026-06-05T09:15:00Z", status: .filled,
                profit: 32.50, pnlPct: 3.18, dataSource: nil),
            Order(id: 1002, strategyId: 1, symbol: "BTC/USDT", side: .sell,
                orderType: .market, quantity: 0.015, price: nil,
                filledPrice: 68650.00, fee: 1.54, slippage: 0.005,
                timestamp: "2026-06-05T10:30:00Z", status: .filled,
                profit: nil, pnlPct: nil, dataSource: nil),
            Order(id: 1003, strategyId: 1, symbol: "BTC/USDT", side: .buy,
                orderType: .limit, quantity: 0.020, price: 67800.00,
                filledPrice: nil, fee: 0.0, slippage: 0.0,
                timestamp: "2026-06-05T11:00:00Z", status: .pending,
                profit: nil, pnlPct: nil, dataSource: nil),
        ]
    }

    static func ledger(runId: String) -> [AnyCodable] {
        [
            AnyCodable(["id": UUID().uuidString, "run_id": runId,
                "entry_type": "trade_pnl", "amount": 32.50, "balance": 10032.50,
                "description": "BTC/USDT long closed +3.18%",
                "created_at": "2026-06-05T10:30:02Z"] as [String: Any]),
            AnyCodable(["id": UUID().uuidString, "run_id": runId,
                "entry_type": "fee", "amount": -2.57, "balance": 10029.93,
                "description": "Trading fees for BTC/USDT round-trip",
                "created_at": "2026-06-05T10:30:02Z"] as [String: Any]),
            AnyCodable(["id": UUID().uuidString, "run_id": runId,
                "entry_type": "funding", "amount": -0.85, "balance": 10029.08,
                "description": "Funding rate charge",
                "created_at": "2026-06-05T08:00:00Z"] as [String: Any]),
        ]
    }
}
