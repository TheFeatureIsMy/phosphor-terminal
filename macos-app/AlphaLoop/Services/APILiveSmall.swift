// APILiveSmall.swift — Live-Small pre-flight checks (precondition / evaluate / config preview / circuit breaker)

import Foundation

final class APILiveSmall: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - Precondition Check (7-gate)

    func preconditionCheck(body: [String: Any]) async throws -> LiveSmallPrecondition {
        try await client.post("/api/v2/live-small/precondition", body: AnyEncodable(body), mock: {
            MockLiveSmallData.precondition()
        })
    }

    // MARK: - Evaluate

    func evaluate(body: [String: Any]) async throws -> LiveSmallEvaluation {
        try await client.post("/api/v2/live-small/evaluate", body: AnyEncodable(body), mock: {
            LiveSmallEvaluation(
                canExecute: true,
                requiresHumanConfirm: true,
                preconditions: [
                    LiveSmallPrecondition(gateName: "backtest_sharpe", passed: true, message: "Sharpe 1.82 >= 1.0"),
                    LiveSmallPrecondition(gateName: "balance_sufficient", passed: true, message: "可用余额 $2,340 >= 所需 $500"),
                ],
                riskSummary: AnyCodable("策略符合上线标准，建议以 5% 仓位启动观察期")
            )
        })
    }

    // MARK: - Config Preview

    func configPreview(body: [String: Any]) async throws -> [String: AnyCodable] {
        try await client.post("/api/v2/live-small/config-preview", body: AnyEncodable(body), mock: {
            [
                "stake_amount": AnyCodable(50.0),
                "max_open_trades": AnyCodable(3),
                "stop_loss_pct": AnyCodable(-0.02),
                "take_profit_pct": AnyCodable(0.04),
                "exchange": AnyCodable("binance"),
                "trading_mode": AnyCodable("spot"),
                "dry_run": AnyCodable(false),
            ]
        })
    }

    // MARK: - Circuit Breaker Check

    func circuitBreakerCheck(body: [String: Any]) async throws -> [String: AnyCodable] {
        try await client.post("/api/v2/live-small/circuit-breaker", body: AnyEncodable(body), mock: {
            [
                "tripped": AnyCodable(false),
                "max_daily_loss_pct": AnyCodable(-0.05),
                "current_daily_loss_pct": AnyCodable(-0.012),
                "max_consecutive_losses": AnyCodable(5),
                "current_consecutive_losses": AnyCodable(1),
                "cooldown_remaining_sec": AnyCodable(0),
            ]
        })
    }
}

// MARK: - Mock data

enum MockLiveSmallData {
    static func precondition() -> LiveSmallPrecondition {
        LiveSmallPrecondition(
            gateName: "correlation_check",
            passed: false,
            message: "与已运行策略 RSI-均值回归 相关性 0.87 超过 0.7 阈值"
        )
    }
}
