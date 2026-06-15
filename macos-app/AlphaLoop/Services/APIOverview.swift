// APIOverview.swift — Overview BFF API (Dashboard + Live Readiness + Global Status)

import Foundation

// MARK: - Response Types

struct AvailableActionResponse: Codable, Hashable {
    let type: String
    let enabled: Bool
    let label: String
    var confirmRequired: Bool = false

    enum CodingKeys: String, CodingKey {
        case type, enabled, label
        case confirmRequired = "confirm_required"
    }
}

struct AccountOverviewResponse: Codable {
    let equity: Double
    let currency: String
    var todayPnlPct: Double = 0
    var weekPnlPct: Double = 0
    var maxDrawdownPct: Double = 0
    var sharpeRatio: Double?

    enum CodingKeys: String, CodingKey {
        case equity, currency
        case todayPnlPct = "today_pnl_pct"
        case weekPnlPct = "week_pnl_pct"
        case maxDrawdownPct = "max_drawdown_pct"
        case sharpeRatio = "sharpe_ratio"
    }
}

struct RuntimeOverviewResponse: Codable {
    var runningStrategies: Int = 0
    var openPositions: Int = 0
    var pendingOrders: Int = 0
    var reconcilingCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case runningStrategies = "running_strategies"
        case openPositions = "open_positions"
        case pendingOrders = "pending_orders"
        case reconcilingCount = "reconciling_count"
    }
}

struct RiskOverviewResponse: Codable {
    var globalState: String = "normal"
    var dailyLossRemainingPct: Double = 0
    var weeklyLossRemainingPct: Double = 0
    var emergencyLocked: Bool = false
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case globalState = "global_state"
        case dailyLossRemainingPct = "daily_loss_remaining_pct"
        case weeklyLossRemainingPct = "weekly_loss_remaining_pct"
        case emergencyLocked = "emergency_locked"
        case reasonCodes = "reason_codes"
    }
}

struct SystemOverviewResponse: Codable {
    var liveReadinessState: String = "NOT_READY"
    var fastTrackLatencyMs: Int = 0
    var redisRttMs: Int = 0
    var freqtradeState: String = "unknown"
    var exchangeState: String = "unknown"

    enum CodingKeys: String, CodingKey {
        case liveReadinessState = "live_readiness_state"
        case fastTrackLatencyMs = "fast_track_latency_ms"
        case redisRttMs = "redis_rtt_ms"
        case freqtradeState = "freqtrade_state"
        case exchangeState = "exchange_state"
    }
}

struct RecentDecisionResponse: Codable {
    var time: String?
    var symbol: String = ""
    var decision: String = ""
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case time, symbol, decision
        case reasonCodes = "reason_codes"
    }
}

struct AlertResponse: Codable {
    var level: String = "info"
    var title: String = ""
    var symbol: String = ""
    var time: String?
}

struct DashboardBFFResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var account: AccountOverviewResponse = AccountOverviewResponse(equity: 0, currency: "USDT")
    var runtime: RuntimeOverviewResponse = RuntimeOverviewResponse()
    var risk: RiskOverviewResponse = RiskOverviewResponse()
    var system: SystemOverviewResponse = SystemOverviewResponse()
    var recentDecisions: [RecentDecisionResponse] = []
    var alerts: [AlertResponse] = []

    enum CodingKeys: String, CodingKey {
        case state
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case account, runtime, risk, system
        case recentDecisions = "recent_decisions"
        case alerts
    }
}

struct ReadinessCheckResponse: Codable {
    let key: String
    let label: String
    var status: String = "unknown"
    var value: String = ""
    var threshold: String = ""
}

struct LiveReadinessResponse: Codable {
    var state: String = "NOT_READY"
    var score: Int = 0
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var canStartPaper: Bool = false
    var canStartLiveSmall: Bool = false
    var canStartFullLive: Bool = false
    var blockingReasons: [[String: String]] = []
    var warnings: [[String: String]] = []
    var checks: [ReadinessCheckResponse] = []

    enum CodingKeys: String, CodingKey {
        case state, score, checks, warnings
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case canStartPaper = "can_start_paper"
        case canStartLiveSmall = "can_start_live_small"
        case canStartFullLive = "can_start_full_live"
        case blockingReasons = "blocking_reasons"
    }
}

struct GlobalStatusBFFResponse: Codable {
    var systemState: String = "NOT_READY"
    var riskState: String = "normal"
    var fastTrackLatencyMs: Int = 0
    var freqtradeState: String = "unknown"
    var redisRttMs: Int = 0
    var exchangeState: String = "unknown"
    var openPositions: Int = 0
    var emergencyLocked: Bool = false
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case systemState = "system_state"
        case riskState = "risk_state"
        case fastTrackLatencyMs = "fast_track_latency_ms"
        case freqtradeState = "freqtrade_state"
        case redisRttMs = "redis_rtt_ms"
        case exchangeState = "exchange_state"
        case openPositions = "open_positions"
        case emergencyLocked = "emergency_locked"
        case reasonCodes = "reason_codes"
    }
}

// MARK: - API Service

struct APIOverview {
    let client: NetworkClientProtocol

    func getDashboard() async throws -> DashboardBFFResponse {
        try await client.get("/api/overview/dashboard", mock: MockOverview.dashboard)
    }

    func getLiveReadiness() async throws -> LiveReadinessResponse {
        try await client.get("/api/overview/live-readiness", mock: MockOverview.liveReadiness)
    }

    func runReadinessCheck() async throws -> LiveReadinessResponse {
        try await client.get("/api/overview/live-readiness", mock: MockOverview.liveReadiness)
    }

    func getGlobalStatus() async throws -> GlobalStatusBFFResponse {
        try await client.get("/api/overview/global-status", mock: MockOverview.globalStatus)
    }
}

// MARK: - Mock Data

enum MockOverview {
    static func dashboard() -> DashboardBFFResponse {
        DashboardBFFResponse(
            state: "healthy",
            availableActions: [AvailableActionResponse(type: "emergency_stop", enabled: true, label: "紧急停止", confirmRequired: true)],
            account: AccountOverviewResponse(equity: 10248.32, currency: "USDT", todayPnlPct: 0.012, weekPnlPct: 0.038, maxDrawdownPct: 0.041),
            runtime: RuntimeOverviewResponse(runningStrategies: 2, openPositions: 3, pendingOrders: 1),
            risk: RiskOverviewResponse(globalState: "normal", dailyLossRemainingPct: 0.76, weeklyLossRemainingPct: 0.81),
            system: SystemOverviewResponse(liveReadinessState: "LIVE_SMALL_READY", fastTrackLatencyMs: 45, redisRttMs: 3, freqtradeState: "healthy", exchangeState: "ok"),
            recentDecisions: [RecentDecisionResponse(symbol: "BTC/USDT", decision: "reduce_size", reasonCodes: ["ai_cache_soft_expired", "shadow_warning"])],
            alerts: [AlertResponse(level: "warning", title: "1h Shadow OB temporary violation", symbol: "BTC/USDT")]
        )
    }

    static func liveReadiness() -> LiveReadinessResponse {
        LiveReadinessResponse(
            state: "LIVE_SMALL_READY", score: 86,
            canStartPaper: true, canStartLiveSmall: true, canStartFullLive: false,
            warnings: [["code": "exchange_api_weight_warning", "message": "交易所 API 权重剩余偏低"]],
            checks: [
                ReadinessCheckResponse(key: "fast_track", label: "Fast Track", status: "healthy", value: "45ms", threshold: "<200ms"),
                ReadinessCheckResponse(key: "redis", label: "Redis RTT", status: "healthy", value: "3ms", threshold: "<50ms"),
                ReadinessCheckResponse(key: "freqtrade", label: "Freqtrade", status: "healthy", value: "running", threshold: "running"),
                ReadinessCheckResponse(key: "exchange", label: "交易所 API", status: "warning", value: "weight 80%", threshold: "<90%"),
            ]
        )
    }

    static func globalStatus() -> GlobalStatusBFFResponse {
        GlobalStatusBFFResponse(
            systemState: "LIVE_SMALL_READY", riskState: "normal",
            fastTrackLatencyMs: 45, freqtradeState: "healthy",
            redisRttMs: 3, exchangeState: "ok", openPositions: 3
        )
    }
}
