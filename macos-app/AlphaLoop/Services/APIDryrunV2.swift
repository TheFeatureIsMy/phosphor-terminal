// APIDryrunV2.swift — v2 Dryrun API (start, stop, status, list)

import Foundation

struct APIDryrunV2 {
    let client: NetworkClientProtocol

    func startDryrun(_ body: [String: Any]) async throws -> DryRunCommandResponse {
        try await client.post("/api/v2/dryrun", body: AnyEncodable(body)) {
            DryRunCommandResponse(
                commandId: UUID().uuidString,
                status: "pending"
            )
        }
    }

    func stopDryrun(_ id: String) async throws -> DryRunCommandResponse {
        try await client.post("/api/v2/dryrun/\(id)/stop", body: AnyEncodable([String: String]())) {
            DryRunCommandResponse(
                commandId: id,
                status: "stopping"
            )
        }
    }

    func getDryrunStatus(_ commandId: String) async throws -> DryRunStatusV2 {
        try await client.get("/api/v2/dryrun/status/\(commandId)") {
            DryRunStatusV2(
                commandId: commandId,
                status: "running",
                result: AnyCodable([
                    "run_id": UUID().uuidString,
                    "strategy_name": "RSI Mean Reversion",
                    "symbol": "BTC/USDT",
                    "exchange": "binance",
                    "started_at": "2026-06-05T08:00:00Z",
                    "total_trades": 5,
                    "win_rate": 0.60,
                    "total_pnl": 128.45,
                    "current_balance": 10128.45,
                ] as [String: Any])
            )
        }
    }

    func listDryruns(limit: Int = 20) async throws -> [DryRunStatusV2] {
        try await client.get("/api/v2/dryrun?limit=\(limit)") {
            [
                DryRunStatusV2(
                    commandId: UUID().uuidString,
                    status: "running",
                    result: AnyCodable([
                        "strategy_name": "RSI Mean Reversion",
                        "symbol": "BTC/USDT",
                        "exchange": "binance",
                        "total_trades": 5,
                        "win_rate": 0.60,
                        "total_pnl": 128.45,
                    ] as [String: Any])
                ),
                DryRunStatusV2(
                    commandId: UUID().uuidString,
                    status: "completed",
                    result: AnyCodable([
                        "strategy_name": "MACD Crossover",
                        "symbol": "ETH/USDT",
                        "exchange": "binance",
                        "total_trades": 18,
                        "win_rate": 0.56,
                        "total_pnl": 312.70,
                    ] as [String: Any])
                ),
                DryRunStatusV2(
                    commandId: UUID().uuidString,
                    status: "error",
                    result: AnyCodable([
                        "strategy_name": "Bollinger Breakout",
                        "symbol": "SOL/USDT",
                        "error_code": "INSUFFICIENT_BALANCE",
                        "error_message": "Insufficient balance for initial stake amount",
                    ] as [String: Any])
                ),
            ]
        }
    }
}
