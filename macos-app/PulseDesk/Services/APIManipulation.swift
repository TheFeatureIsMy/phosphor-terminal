// APIManipulation.swift — Manipulation Detection API (scan, scores)

import Foundation

struct APIManipulation {
    let client: NetworkClientProtocol

    func scanSymbol(_ body: [String: Any]) async throws -> ManipulationScoreV2 {
        try await client.post("/api/v2/manipulation/scan", body: AnyEncodable(body)) {
            ManipulationScoreV2(
                id: UUID().uuidString,
                symbol: "BTC/USDT",
                manipulationScore: 0.35,
                stopHuntScore: 0.28,
                holderConcentrationScore: 0.22,
                liquidityTrapScore: 0.42,
                pumpDumpScore: 0.15,
                fundingSqueezeScore: 0.20,
                riskLevel: "medium",
                suggestion: "Exercise caution — moderate manipulation signals detected. Elevated liquidity trap score on 15m candles. Consider reducing position size.",
                updatedAt: "2026-06-05T12:00:00Z"
            )
        }
    }

    func listScores(limit: Int = 20) async throws -> [ManipulationScoreV2] {
        try await client.get("/api/v2/manipulation/scores?limit=\(limit)") {
            [
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "BTC/USDT",
                    manipulationScore: 0.18,
                    stopHuntScore: 0.10,
                    holderConcentrationScore: 0.15,
                    liquidityTrapScore: 0.12,
                    pumpDumpScore: 0.08,
                    fundingSqueezeScore: 0.05,
                    riskLevel: "low",
                    suggestion: "Market appears clean. Normal trading conditions.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "ETH/USDT",
                    manipulationScore: 0.62,
                    stopHuntScore: 0.55,
                    holderConcentrationScore: 0.48,
                    liquidityTrapScore: 0.70,
                    pumpDumpScore: 0.45,
                    fundingSqueezeScore: 0.72,
                    riskLevel: "high",
                    suggestion: "High manipulation risk. Stop-hunt activity detected near key liquidation levels. Abnormal funding squeeze pattern. Avoid new entries until conditions normalize.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "SOL/USDT",
                    manipulationScore: 0.85,
                    stopHuntScore: 0.82,
                    holderConcentrationScore: 0.90,
                    liquidityTrapScore: 0.78,
                    pumpDumpScore: 0.88,
                    fundingSqueezeScore: 0.75,
                    riskLevel: "critical",
                    suggestion: "Critical manipulation alert. Extreme holder concentration with coordinated pump-dump pattern. Volume 8x rolling 7-day average with no catalyst. Do NOT trade this pair.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "DOGE/USDT",
                    manipulationScore: 0.05,
                    stopHuntScore: 0.03,
                    holderConcentrationScore: 0.08,
                    liquidityTrapScore: 0.04,
                    pumpDumpScore: 0.02,
                    fundingSqueezeScore: 0.03,
                    riskLevel: "low",
                    suggestion: "Market appears clean. Normal trading conditions.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
            ]
        }
    }

    func getScore(_ symbol: String) async throws -> ManipulationScoreV2 {
        try await client.get("/api/v2/manipulation/scores/\(symbol)") {
            ManipulationScoreV2(
                id: UUID().uuidString,
                symbol: symbol,
                manipulationScore: 0.35,
                stopHuntScore: 0.28,
                holderConcentrationScore: 0.22,
                liquidityTrapScore: 0.42,
                pumpDumpScore: 0.15,
                fundingSqueezeScore: 0.20,
                riskLevel: "medium",
                suggestion: "Exercise caution — moderate manipulation signals detected. Elevated liquidity trap score on 15m candles.",
                updatedAt: "2026-06-05T12:00:00Z"
            )
        }
    }
}
