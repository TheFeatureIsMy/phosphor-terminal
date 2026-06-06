// APISignalsV2.swift — v2 Signal API (CRUD + transitions + conflict + aggregation)

import Foundation

struct APISignalsV2 {
    let client: NetworkClientProtocol

    func createSignal(_ body: [String: Any]) async throws -> SignalV2 {
        try await client.post("/api/v2/signals", body: AnyEncodable(body)) {
            SignalV2(
                id: UUID().uuidString, sourceType: "ai_research", symbol: "BTC/USDT",
                direction: "long", confidence: 0.85, score: 4.2, riskLevel: "medium",
                status: "pending", expiresAt: "2026-06-06T00:00:00Z",
                createdAt: "2026-06-05T12:00:00Z",
                reasoning: "Strong RSI divergence detected"
            )
        }
    }

    func listSignals(symbol: String? = nil, status: String? = nil, limit: Int = 50) async throws -> [SignalV2] {
        var path = "/api/v2/signals?limit=\(limit)"
        if let symbol { path += "&symbol=\(symbol)" }
        if let status { path += "&status=\(status)" }
        return try await client.get(path) {
            [
                SignalV2(
                    id: UUID().uuidString, sourceType: "ai_research", symbol: "BTC/USDT",
                    direction: "long", confidence: 0.85, score: 4.2, riskLevel: "medium",
                    status: "active", expiresAt: "2026-06-06T00:00:00Z",
                    createdAt: "2026-06-05T10:00:00Z", reasoning: "RSI divergence"
                ),
                SignalV2(
                    id: UUID().uuidString, sourceType: "tradingagents", symbol: "ETH/USDT",
                    direction: "short", confidence: 0.72, score: 3.5, riskLevel: "high",
                    status: "pending", expiresAt: "2026-06-06T00:00:00Z",
                    createdAt: "2026-06-05T09:00:00Z", reasoning: "Bearish engulfing on 4H"
                ),
                SignalV2(
                    id: UUID().uuidString, sourceType: "manual", symbol: "SOL/USDT",
                    direction: "long", confidence: 0.60, score: 3.0, riskLevel: "low",
                    status: "active", expiresAt: "2026-06-07T00:00:00Z",
                    createdAt: "2026-06-05T08:00:00Z", reasoning: "Support bounce"
                ),
            ]
        }
    }

    func getSignal(_ id: String) async throws -> SignalV2 {
        try await client.get("/api/v2/signals/\(id)") {
            SignalV2(
                id: id, sourceType: "ai_research", symbol: "BTC/USDT",
                direction: "long", confidence: 0.85, score: 4.2, riskLevel: "medium",
                status: "active", expiresAt: "2026-06-06T00:00:00Z",
                createdAt: "2026-06-05T10:00:00Z",
                reasoning: "RSI divergence with volume confirmation"
            )
        }
    }

    func transitionSignal(_ id: String, targetStatus: String, reason: String? = nil) async throws -> SignalV2 {
        try await client.post(
            "/api/v2/signals/\(id)/transition",
            body: AnyEncodable(["target_status": targetStatus, "reason": reason ?? ""])
        ) {
            SignalV2(
                id: id, sourceType: "ai_research", symbol: "BTC/USDT",
                direction: "long", confidence: 0.85, score: 4.2, riskLevel: "medium",
                status: targetStatus, expiresAt: "2026-06-06T00:00:00Z",
                createdAt: "2026-06-05T10:00:00Z"
            )
        }
    }

    func archiveSignal(_ id: String) async throws -> SignalV2 {
        try await client.post("/api/v2/signals/\(id)/archive", body: AnyEncodable([String: String]())) {
            SignalV2(
                id: id, sourceType: "ai_research", symbol: "BTC/USDT",
                direction: "long", confidence: 0.85, score: 4.2, riskLevel: "medium",
                status: "archived", expiresAt: "2026-06-06T00:00:00Z",
                createdAt: "2026-06-05T10:00:00Z"
            )
        }
    }

    func publishToStrategy(_ id: String) async throws -> AnyCodable {
        try await client.post("/api/v2/signals/\(id)/publish-to-strategy", body: AnyEncodable([String: String]())) {
            AnyCodable(["strategy_draft_id": UUID().uuidString, "message": "Strategy draft created"])
        }
    }

    func conflictCheck(symbol: String, direction: String) async throws -> SignalConflictResult {
        try await client.post(
            "/api/v2/signals/conflict-check",
            body: AnyEncodable(["symbol": symbol, "direction": direction])
        ) {
            SignalConflictResult(hasConflict: false, conflictingSignals: [])
        }
    }

    func aggregate(groupBy: String = "symbol") async throws -> SignalAggregateResult {
        try await client.post("/api/v2/signals/aggregate", body: AnyEncodable(["group_by": groupBy])) {
            SignalAggregateResult(groups: [], totalCount: 0)
        }
    }
}
