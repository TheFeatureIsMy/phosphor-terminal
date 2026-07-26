// APIOverview.swift — Overview BFF API (Dashboard + Live Readiness + Global Status)
// Extended for Dashboard v2: parallel fetches for KPIs / positions / orders /
// provider health / AI model status / agent signals.

import Foundation

// MARK: - Action / System

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

struct ReadinessCheckResponse: Codable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    var status: String = "unknown"
    var value: String = ""
    var threshold: String = ""
    var detail: String = ""
    var group: String = "system"

    enum CodingKeys: String, CodingKey {
        case key, label, status, value, threshold, detail, group
    }
}

struct ReadinessOption: Codable, Hashable, Identifiable {
    var id: String { key }
    var key: String = ""
    var name: String = ""
    var kind: String?
    var detail: String?

    enum CodingKeys: String, CodingKey {
        case key, name, kind, detail, id
    }

    init() {}

    init(key: String, name: String, kind: String? = nil, detail: String? = nil) {
        self.key = key
        self.name = name
        self.kind = kind
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? (try c.decodeIfPresent(String.self, forKey: .id) ?? "")
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(kind, forKey: .kind)
        try c.encodeIfPresent(detail, forKey: .detail)
    }
}

struct ReadinessReason: Codable, Hashable, Identifiable {
    var id: String { code }
    let code: String
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, message
    }

    init(code: String, message: String? = nil) {
        self.code = code
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        message = try? c.decode(String.self, forKey: .message)
    }
}

struct LiveReadinessResponse: Codable {
    var state: String = "NOT_READY"
    var grandStatus: String = "not_live"
    var score: Int = 0
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var canStartPaper: Bool = false
    var canStartLiveSmall: Bool = false
    var canStartFullLive: Bool = false
    var blockingReasons: [ReadinessReason] = []
    var warnings: [ReadinessReason] = []
    var checks: [ReadinessCheckResponse] = []

    // Selection context
    var selectedMode: String = ""
    var selectedStrategyId: String = ""
    var selectedCapitalPoolId: String = ""
    var selectedExchange: String = ""

    // Available options for pickers
    var availableStrategies: [ReadinessOption] = []
    var availableCapitalPools: [ReadinessOption] = []
    var availableExchanges: [ReadinessOption] = []

    enum CodingKeys: String, CodingKey {
        case state
        case grandStatus = "grand_status"
        case score, checks, warnings
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case canStartPaper = "can_start_paper"
        case canStartLiveSmall = "can_start_live_small"
        case canStartFullLive = "can_start_full_live"
        case blockingReasons = "blocking_reasons"
        case selectedMode = "selected_mode"
        case selectedStrategyId = "selected_strategy_id"
        case selectedCapitalPoolId = "selected_capital_pool_id"
        case selectedExchange = "selected_exchange"
        case availableStrategies = "available_strategies"
        case availableCapitalPools = "available_capital_pools"
        case availableExchanges = "available_exchanges"
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

// MARK: - Dashboard v2 Supplementary Types

/// Mirrors backend `GET /api/dashboard/kpis` (freqtrade DB + simulated fallback).
struct DashboardKPIsResponse: Codable {
    var totalPnl: Double = 0
    var pnlChangePct: Double = 0
    var sharpeRatio: Double = 0
    var maxDrawdown: Double = 0
    var winRate: Double = 0
    var activeStrategies: Int = 0
    var todaysTrades: Int = 0
    var openPositions: Int = 0
    var dataSource: DataSourceRef?

    enum CodingKeys: String, CodingKey {
        case totalPnl = "total_pnl"
        case pnlChangePct = "pnl_change_pct"
        case sharpeRatio = "sharpe_ratio"
        case maxDrawdown = "max_drawdown"
        case winRate = "win_rate"
        case activeStrategies = "active_strategies"
        case todaysTrades = "todays_trades"
        case openPositions = "open_positions"
        case dataSource = "data_source"
    }
}

struct DataSourceRef: Codable, Hashable {
    var kind: String = "unknown"
    var detail: String?
    var isSimulated: Bool = false

    enum CodingKeys: String, CodingKey {
        case kind, detail
        case isSimulated = "is_simulated"
    }
}

/// Aggregate provider health for the Dashboard.
struct ProviderHealthSummary: Codable, Hashable {
    var total: Int = 0
    var totalActive: Int = 0
    var totalError: Int = 0
    var totalDisabled: Int = 0
    var totalConfigured: Int = 0
    var byCategory: [String: Int] = [:]
    var checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case total
        case totalActive = "total_active"
        case totalError = "total_error"
        case totalDisabled = "total_disabled"
        case totalConfigured = "total_configured"
        case byCategory = "by_category"
        case checkedAt = "checked_at"
    }
}

struct ProviderHealthEntry: Codable, Hashable, Identifiable {
    var id: Int
    var category: String
    var providerName: String
    var enabled: Bool
    var isActive: Bool
    var status: String
    var credentialStatus: String
    var lastError: String?
    var latencyMs: Int?

    enum CodingKeys: String, CodingKey {
        case id, category, enabled, status
        case providerName = "provider_name"
        case isActive = "is_active"
        case credentialStatus = "credential_status"
        case lastError = "last_error"
        case latencyMs = "latency_ms"
    }
}

/// Slim view of AI model runtime status (from `/api/ai/models/runtime`).
struct AIModelStatusRef: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var provider: String
    var state: String
    var modelId: String?
    var gpuMemoryMb: Int?

    enum CodingKeys: String, CodingKey {
        case name, provider, state
        case modelId = "model_id"
        case gpuMemoryMb = "gpu_memory_mb"
    }
}

/// Slim view of an agent signal (from `/api/agent-signals/signals`) with
/// explicit `source_*` trace fields for the Dashboard "traceable source" requirement.
struct DashboardSignalRef: Codable, Hashable, Identifiable {
    var id: Int
    var symbol: String
    var market: String
    var direction: String?
    var rating: String?
    var confidence: Double?
    var overallScore: Double?
    var content: String
    var createdAt: String

    // Traceability
    var sourceAgent: String?
    var sourceStrategyId: String?
    var sourceFeatureSnapshotId: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol, market, direction, rating, confidence, content
        case overallScore = "overall_score"
        case createdAt = "created_at"
        case sourceAgent = "source_agent"
        case sourceStrategyId = "source_strategy_id"
        case sourceFeatureSnapshotId = "source_feature_snapshot_id"
    }
}

// MARK: - API Service

struct APIOverview {
    let client: NetworkClientProtocol

    // BFF endpoints (kept as-is)
    func getDashboard() async throws -> DashboardBFFResponse {
        try await client.get("/api/overview/dashboard")
    }

    func getLiveReadiness() async throws -> LiveReadinessResponse {
        try await client.get("/api/overview/live-readiness")
    }

    func runReadinessCheck(
        mode: String = "live_small",
        strategyId: String = "",
        capitalPoolId: String = "",
        exchange: String = "binance"
    ) async throws -> LiveReadinessResponse {
        var path = "/api/overview/live-readiness"
        var query: [String] = []
        query.append("mode=\(mode)")
        if !strategyId.isEmpty { query.append("strategy_id=\(strategyId)") }
        if !capitalPoolId.isEmpty { query.append("capital_pool_id=\(capitalPoolId)") }
        query.append("exchange=\(exchange)")
        path += "?" + query.joined(separator: "&")
        return try await client.get(path)
    }

    func getGlobalStatus() async throws -> GlobalStatusBFFResponse {
        try await client.get("/api/overview/global-status")
    }

    // Supplementary endpoints (Dashboard v2)
    func getKPIs() async throws -> DashboardKPIsResponse {
        try await client.get("/api/dashboard/kpis")
    }

    func getProviderHealth() async throws -> ProviderHealthSummary {
        try await client.get("/api/admin/providers/categories")
    }

    func getAIModelStatus() async throws -> [AIModelStatusRef] {
        struct Response: Decodable { let models: [AIModelStatusRef] }
        let resp: Response = try await client.get("/api/ai/models/runtime")
        return resp.models
    }

    func getRecentSignals(limit: Int = 10) async throws -> [DashboardSignalRef] {
        try await client.get(
            "/api/agent-signals/signals?limit=\(limit)",
        )
    }
}

