// APIMTFGuard.swift — MTF Temporal Guard API

import Foundation

struct MTFGuardStateResponse: Codable, Hashable {
    let strategyId: String
    let symbol: String
    let guards: [MTFGuardInfo]

    enum CodingKeys: String, CodingKey {
        case strategyId = "strategy_id"
        case symbol, guards
    }
}

struct MTFGuardInfo: Codable, Identifiable, Hashable {
    var id: String { guardId }
    let guardId: String
    let fastTimeframe: String
    let slowTimeframe: String
    let guardState: String
    let action: String
    let structureType: String
    let reasonCodes: [String]

    enum CodingKeys: String, CodingKey {
        case guardId = "guard_id"
        case fastTimeframe = "fast_timeframe"
        case slowTimeframe = "slow_timeframe"
        case guardState = "guard_state"
        case action
        case structureType = "structure_type"
        case reasonCodes = "reason_codes"
    }

    var stateColor: String {
        switch guardState {
        case "confirmed": "accent"
        case "watching": "amber"
        case "pending_htf_close": "amber"
        case "temporary_violation": "warning"
        case "reclaim_pending": "amber"
        case "invalidated": "danger"
        case "expired": "muted"
        default: "muted"
        }
    }

    var stateLabel: String {
        switch guardState {
        case "confirmed": "已确认"
        case "watching": "监视中"
        case "pending_htf_close": "等待HTF闭合"
        case "temporary_violation": "临时违规"
        case "reclaim_pending": "等待回收"
        case "invalidated": "已失效"
        case "expired": "已过期"
        default: guardState
        }
    }

    var actionLabel: String {
        switch action {
        case "allow": "允许"
        case "observe": "观察"
        case "require_confirm": "需确认"
        case "block_entry": "阻断入场"
        case "reduce_size": "降低仓位"
        case "ignore": "忽略"
        default: action
        }
    }
}

struct MTFGuardEvent: Codable, Identifiable, Hashable {
    let id: String
    let guardState: String
    let action: String
    let fastTimeframe: String
    let slowTimeframe: String
    let structureType: String
    let reasonCodes: [String]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case guardState = "guard_state"
        case action
        case fastTimeframe = "fast_timeframe"
        case slowTimeframe = "slow_timeframe"
        case structureType = "structure_type"
        case reasonCodes = "reason_codes"
        case createdAt = "created_at"
    }
}

struct APIMTFGuard {
    let client: NetworkClientProtocol

    func getGuardState(strategyId: String, symbol: String) async throws -> MTFGuardStateResponse {
        try await client.get(
            "/api/structure/mtf-guard/\(strategyId)/\(symbol)",
            mock: Self.mockState
        )
    }

    func getGuardEvents(strategyId: String) async throws -> [MTFGuardEvent] {
        try await client.get(
            "/api/structure/mtf-guard-events/\(strategyId)",
            mock: Self.mockEvents
        )
    }

    static func mockState() -> MTFGuardStateResponse {
        MTFGuardStateResponse(
            strategyId: "str_001",
            symbol: "BTC/USDT",
            guards: [
                MTFGuardInfo(
                    guardId: "mtf_ob_guard_1",
                    fastTimeframe: "5m",
                    slowTimeframe: "1h",
                    guardState: "watching",
                    action: "observe",
                    structureType: "order_block",
                    reasonCodes: []
                ),
                MTFGuardInfo(
                    guardId: "mtf_fvg_guard_1",
                    fastTimeframe: "15m",
                    slowTimeframe: "4h",
                    guardState: "confirmed",
                    action: "allow",
                    structureType: "fvg",
                    reasonCodes: ["htf_close_confirmed"]
                ),
            ]
        )
    }

    static func mockEvents() -> [MTFGuardEvent] {
        [
            MTFGuardEvent(
                id: "evt_001",
                guardState: "temporary_violation",
                action: "block_entry",
                fastTimeframe: "5m",
                slowTimeframe: "1h",
                structureType: "order_block",
                reasonCodes: ["mtf_temporary_violation", "htf_not_closed"],
                createdAt: "2026-06-08T10:30:00Z"
            ),
        ]
    }
}
