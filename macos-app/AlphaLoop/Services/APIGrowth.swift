// APIGrowth.swift — Growth API (daily review, reports, candidates)

import Foundation

struct APIGrowth {
    let client: NetworkClientProtocol

    func runDailyReview(_ body: [String: Any]) async throws -> GrowthReport {
        try await client.post("/api/v2/growth/daily-review", body: AnyEncodable(body)) {
            GrowthReport(
                id: UUID().uuidString,
                reportType: "daily_review",
                status: "completed",
                summary: AnyCodable([
                    "report_date": "2026-06-05",
                    "total_strategies_reviewed": 8,
                    "candidates_found": 3,
                    "top_performer": "RSI Mean Reversion",
                    "top_performer_pnl": 1245.80,
                    "avg_win_rate": 0.62,
                    "avg_sharpe_ratio": 1.35,
                    "recommendations": [
                        "Increase position size on RSI Mean Reversion (consistent alpha)",
                        "Consider pausing MACD Crossover (negative Sharpe last 7 days)",
                        "New candidate: Volume Breakout shows promise on SOL/USDT",
                    ],
                ] as [String: Any]),
                createdAt: "2026-06-05T06:00:00Z"
            )
        }
    }

    func listReports(limit: Int = 20) async throws -> [GrowthReport] {
        try await client.get("/api/v2/growth/reports?limit=\(limit)") {
            [
                GrowthReport(
                    id: UUID().uuidString,
                    reportType: "daily_review",
                    status: "completed",
                    summary: AnyCodable([
                        "report_date": "2026-06-05",
                        "total_strategies_reviewed": 8,
                        "candidates_found": 3,
                        "top_performer": "RSI Mean Reversion",
                        "avg_win_rate": 0.62,
                    ] as [String: Any]),
                    createdAt: "2026-06-05T06:00:00Z"
                ),
                GrowthReport(
                    id: UUID().uuidString,
                    reportType: "daily_review",
                    status: "completed",
                    summary: AnyCodable([
                        "report_date": "2026-06-04",
                        "total_strategies_reviewed": 7,
                        "candidates_found": 1,
                        "top_performer": "MACD Crossover",
                        "avg_win_rate": 0.58,
                    ] as [String: Any]),
                    createdAt: "2026-06-04T06:00:00Z"
                ),
                GrowthReport(
                    id: UUID().uuidString,
                    reportType: "daily_review",
                    status: "failed",
                    summary: nil,
                    createdAt: "2026-06-03T06:00:00Z"
                ),
            ]
        }
    }

    func listCandidates(limit: Int = 20) async throws -> [StrategyCandidate] {
        try await client.get("/api/v2/growth/candidates?limit=\(limit)") {
            [
                StrategyCandidate(
                    id: UUID().uuidString,
                    status: "pending_review",
                    confidence: 0.82,
                    createdAt: "2026-06-05T06:15:00Z",
                    dsl: AnyCodable([
                        "name": "Volume Breakout v2",
                        "symbol": "SOL/USDT",
                        "source_type": "ai_generated",
                        "backtest_win_rate": 0.68,
                        "backtest_sharpe": 1.72,
                        "reasoning": "Strong volume profile breakout pattern on 4H timeframe",
                    ] as [String: Any])
                ),
                StrategyCandidate(
                    id: UUID().uuidString,
                    status: "confirmed",
                    confidence: 0.91,
                    createdAt: "2026-06-04T14:30:00Z",
                    dsl: AnyCodable([
                        "name": "Funding Rate Arb",
                        "symbol": "BTC/USDT",
                        "source_type": "manual",
                        "backtest_win_rate": 0.82,
                        "backtest_sharpe": 2.10,
                        "reasoning": "Exploits funding rate divergence between perpetual and quarterly contracts",
                    ] as [String: Any])
                ),
                StrategyCandidate(
                    id: UUID().uuidString,
                    status: "rejected",
                    confidence: 0.35,
                    createdAt: "2026-06-03T20:00:00Z",
                    dsl: AnyCodable([
                        "name": "Momentum Scalper",
                        "symbol": "ETH/USDT",
                        "source_type": "ai_generated",
                        "backtest_win_rate": 0.51,
                        "backtest_sharpe": 0.45,
                        "reasoning": "Rejected — poor risk-adjusted returns on 1m momentum",
                    ] as [String: Any])
                ),
            ]
        }
    }

    func confirmCandidate(_ id: String) async throws -> StrategyCandidate {
        try await client.post("/api/v2/growth/candidates/\(id)/confirm", body: AnyEncodable([String: String]())) {
            StrategyCandidate(
                id: id,
                status: "confirmed",
                confidence: 0.82,
                createdAt: "2026-06-05T06:15:00Z",
                dsl: AnyCodable([
                    "name": "Volume Breakout v2",
                    "symbol": "SOL/USDT",
                    "reasoning": "Confirmed for dryrun deployment",
                ] as [String: Any])
            )
        }
    }
}


// MARK: - SHAP & Signal Validity Response Types

struct ShapFeatureItem: Codable {
    let name: String
    let value: Double
}

struct ShapFeaturesResponse: Codable {
    let state: String
    let features: [ShapFeatureItem]
}

struct SignalSourceItem: Codable {
    let name: String
    let accuracy: Double
    let total: Int
}

struct SignalValidityResponse: Codable {
    let state: String
    let sources: [SignalSourceItem]
}

// MARK: - APIGrowth SHAP & Signal Validity Extensions

extension APIGrowth {
    func getShapFeatures() async throws -> ShapFeaturesResponse {
        try await client.get("/api/growth/shap-features") {
            ShapFeaturesResponse(state: "healthy", features: [
                ShapFeatureItem(name: "RSI_14", value: 0.312),
                ShapFeatureItem(name: "MACD_hist", value: 0.248),
                ShapFeatureItem(name: "Vol_24h", value: 0.201),
                ShapFeatureItem(name: "BB_width", value: 0.178),
                ShapFeatureItem(name: "EMA_cross", value: 0.156),
                ShapFeatureItem(name: "ATR_14", value: 0.123),
                ShapFeatureItem(name: "OBV_slope", value: 0.098),
                ShapFeatureItem(name: "ADX_14", value: 0.087),
                ShapFeatureItem(name: "Funding_rate", value: 0.065),
                ShapFeatureItem(name: "Sentiment", value: 0.042),
            ])
        }
    }

    func getSignalValidity() async throws -> SignalValidityResponse {
        try await client.get("/api/growth/signal-validity") {
            SignalValidityResponse(state: "healthy", sources: [
                SignalSourceItem(name: "AI Research", accuracy: 0.72, total: 45),
                SignalSourceItem(name: "TradingAgents", accuracy: 0.68, total: 38),
                SignalSourceItem(name: "Manual", accuracy: 0.61, total: 25),
                SignalSourceItem(name: "Sentiment", accuracy: 0.55, total: 28),
                SignalSourceItem(name: "KOL", accuracy: 0.42, total: 20),
            ])
        }
    }
}
