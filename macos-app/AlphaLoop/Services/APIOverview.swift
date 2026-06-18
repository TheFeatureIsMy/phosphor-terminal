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
    let key: String        // strategy id / pool id / exchange id
    let name: String
    let kind: String?      // e.g. "cex" for exchange
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case key, name, kind, detail
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
    var healthy: Int = 0
    var warning: Int = 0
    var error: Int = 0
    var entries: [ProviderHealthEntry] = []
    var dataSource: DataSourceRef?
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
        try await client.get("/api/overview/dashboard", mock: MockOverview.dashboard)
    }

    func getLiveReadiness() async throws -> LiveReadinessResponse {
        try await client.get("/api/overview/live-readiness", mock: MockOverview.liveReadiness)
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
        return try await client.get(path, mock: MockOverview.liveReadiness)
    }

    func getGlobalStatus() async throws -> GlobalStatusBFFResponse {
        try await client.get("/api/overview/global-status", mock: MockOverview.globalStatus)
    }

    // Supplementary endpoints (Dashboard v2)
    func getKPIs() async throws -> DashboardKPIsResponse {
        try await client.get("/api/dashboard/kpis", mock: MockOverview.dashboardKPIs)
    }

    func getProviderHealth() async throws -> ProviderHealthSummary {
        try await client.get("/api/admin/providers/categories", mock: MockOverview.providerHealth)
    }

    func getAIModelStatus() async throws -> [AIModelStatusRef] {
        try await client.get("/api/ai/models/runtime", mock: MockOverview.aiModels)
    }

    func getRecentSignals(limit: Int = 10) async throws -> [DashboardSignalRef] {
        try await client.get(
            "/api/agent-signals/signals?limit=\(limit)",
            mock: { MockOverview.recentSignals(limit: limit) }
        )
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
            recentDecisions: [],
            alerts: []
        )
    }

    static func liveReadiness() -> LiveReadinessResponse {
        LiveReadinessResponse(
            state: "LIVE_SMALL_READY",
            grandStatus: "ready_for_live",
            score: 86,
            canStartPaper: true, canStartLiveSmall: true, canStartFullLive: false,
            warnings: [ReadinessReason(code: "exchange_api_weight_warning", message: "交易所 API 权重剩余偏低")],
            checks: [
                ReadinessCheckResponse(key: "mode", label: "运行模式", status: "healthy", value: "LIVE_SMALL", threshold: "paper|live_small|live_full", detail: "", group: "mode"),
                ReadinessCheckResponse(key: "strategy", label: "策略选择", status: "healthy", value: "v2:btc-scalp", threshold: "required", detail: "", group: "strategy"),
                ReadinessCheckResponse(key: "capital", label: "资金配置", status: "healthy", value: "cp-1", threshold: "required", detail: "", group: "capital"),
                ReadinessCheckResponse(key: "risk_config", label: "风控配置", status: "healthy", value: "已配置", threshold: "required", detail: "", group: "risk"),
                ReadinessCheckResponse(key: "exchange", label: "交易所连接", status: "warning", value: "weight 80%", threshold: "connected", detail: "API 权重剩余偏低", group: "system"),
                ReadinessCheckResponse(key: "data_source", label: "数据源健康", status: "healthy", value: "online", threshold: "online", detail: "", group: "system"),
                ReadinessCheckResponse(key: "validation", label: "策略 DSL 验证", status: "healthy", value: "通过", threshold: "passed", detail: "", group: "strategy"),
                ReadinessCheckResponse(key: "backtest", label: "回测通过", status: "healthy", value: "通过", threshold: "≥1", detail: "", group: "execution"),
                ReadinessCheckResponse(key: "dryrun", label: "模拟/dry-run", status: "healthy", value: "100h", threshold: "≥72h", detail: "", group: "execution"),
                ReadinessCheckResponse(key: "notification", label: "通知可用", status: "healthy", value: "已配置", threshold: "optional", detail: "", group: "system"),
                ReadinessCheckResponse(key: "emergency_stop", label: "紧急停止", status: "healthy", value: "available", threshold: "available", detail: "", group: "system"),
            ],
            selectedMode: "live_small",
            selectedStrategyId: "v2:btc-scalp",
            selectedCapitalPoolId: "cp-1",
            selectedExchange: "binance",
            availableStrategies: [
                ReadinessOption(key: "v2:btc-scalp", name: "BTC 结构化剥头皮", kind: nil, detail: nil),
                ReadinessOption(key: "v2:eth-fvg", name: "ETH FVG 猎手", kind: nil, detail: nil),
            ],
            availableCapitalPools: [
                ReadinessOption(key: "cp-1", name: "默认资金池", kind: nil, detail: "$500"),
            ],
            availableExchanges: [
                ReadinessOption(key: "binance", name: "Binance", kind: "cex", detail: nil),
                ReadinessOption(key: "okx", name: "OKX", kind: "cex", detail: nil),
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

    static func dashboardKPIs() -> DashboardKPIsResponse {
        DashboardKPIsResponse(
            totalPnl: 12840.75, pnlChangePct: 3.4,
            sharpeRatio: 1.48, maxDrawdown: 12.6, winRate: 63.5,
            activeStrategies: 3, todaysTrades: 8, openPositions: 2,
            dataSource: DataSourceRef(kind: "freqtrade_db", detail: "live", isSimulated: false)
        )
    }

    static func providerHealth() -> ProviderHealthSummary {
        ProviderHealthSummary(
            total: 9, healthy: 7, warning: 1, error: 1,
            entries: [
                ProviderHealthEntry(id: 1, category: "llm", providerName: "Ollama", enabled: true, isActive: true, status: "active", credentialStatus: "configured", lastError: nil, latencyMs: 12),
                ProviderHealthEntry(id: 2, category: "llm", providerName: "OpenAI", enabled: true, isActive: false, status: "error", credentialStatus: "missing", lastError: "API key not configured", latencyMs: nil),
                ProviderHealthEntry(id: 3, category: "cex", providerName: "Binance", enabled: true, isActive: true, status: "active", credentialStatus: "configured", lastError: nil, latencyMs: 22),
                ProviderHealthEntry(id: 4, category: "cex", providerName: "OKX", enabled: true, isActive: false, status: "warning", credentialStatus: "configured", lastError: "rate limit low", latencyMs: 145),
            ],
            dataSource: DataSourceRef(kind: "admin_api", detail: nil, isSimulated: false)
        )
    }

    static func aiModels() -> [AIModelStatusRef] {
        [
            AIModelStatusRef(name: "finbert", provider: "local-gpu", state: "running", modelId: "ProsusAI/finbert", gpuMemoryMb: 2048),
            AIModelStatusRef(name: "chronos", provider: "local-gpu", state: "available", modelId: "amazon/chronos-t5-tiny", gpuMemoryMb: nil),
            AIModelStatusRef(name: "shap", provider: "local-gpu", state: "running", modelId: "lightgbm+shap", gpuMemoryMb: nil),
        ]
    }

    static func recentSignals(limit: Int) -> [DashboardSignalRef] {
        let base: [DashboardSignalRef] = [
            DashboardSignalRef(
                id: 1, symbol: "BTC/USDT", market: "crypto", direction: "long", rating: "Overweight",
                confidence: 0.72, overallScore: 3.8,
                content: "BTC 技术面看多，建议轻仓做多。",
                createdAt: "2026-06-17T10:35:00Z",
                sourceAgent: "tradingagents", sourceStrategyId: "v2:btc-structure-scalp",
                sourceFeatureSnapshotId: "fs-2026-06-17-001"
            ),
            DashboardSignalRef(
                id: 2, symbol: "ETH/USDT", market: "crypto", direction: "long", rating: "Buy",
                confidence: 0.68, overallScore: 3.5,
                content: "ETH 生态活跃度上升，DeFi TVL 增长。",
                createdAt: "2026-06-17T09:18:00Z",
                sourceAgent: "tradingagents", sourceStrategyId: "v2:eth-fvg-hunter",
                sourceFeatureSnapshotId: nil
            ),
            DashboardSignalRef(
                id: 3, symbol: "SOL/USDT", market: "crypto", direction: "short", rating: "Sell",
                confidence: 0.55, overallScore: 2.9,
                content: "SOL 短期超买，建议逢高做空。",
                createdAt: "2026-06-17T08:42:00Z",
                sourceAgent: "manual", sourceStrategyId: nil, sourceFeatureSnapshotId: nil
            ),
        ]
        return Array(base.prefix(limit))
    }
}
