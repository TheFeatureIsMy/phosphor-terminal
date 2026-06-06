// APIFailureClustering.swift — Failure Clustering BFF API

import Foundation

// MARK: - Response Types

struct FailureClusterBFFResponse: Codable, Identifiable {
    var id: String { clusterName }
    let clusterName: String
    var label: String = ""
    var tradeCount: Int = 0
    var totalLoss: Double = 0
    var avgLossPct: Double = 0
    var exampleTradeIds: [String] = []
    var suggestedFix: String = ""
    var severity: String = "medium"

    enum CodingKeys: String, CodingKey {
        case label, severity
        case clusterName = "cluster_name"
        case tradeCount = "trade_count"
        case totalLoss = "total_loss"
        case avgLossPct = "avg_loss_pct"
        case exampleTradeIds = "example_trade_ids"
        case suggestedFix = "suggested_fix"
    }
}

struct RegimeFailureCellResponse: Codable {
    let regime: String
    let failureType: String
    var count: Int = 0
    var totalLoss: Double = 0

    enum CodingKeys: String, CodingKey {
        case regime, count
        case failureType = "failure_type"
        case totalLoss = "total_loss"
    }
}

struct FailureClusteringSummaryResponse: Codable {
    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var totalLossTrades: Int = 0
    var totalLossAmount: Double = 0
    var clusters: [FailureClusterBFFResponse] = []
    var regimeMatrix: [RegimeFailureCellResponse] = []
    var commonRejectReasons: [[String: String]] = []
    var labels: [String] = []

    enum CodingKeys: String, CodingKey {
        case state, clusters, labels
        case reasonCodes = "reason_codes"
        case availableActions = "available_actions"
        case totalLossTrades = "total_loss_trades"
        case totalLossAmount = "total_loss_amount"
        case regimeMatrix = "regime_matrix"
        case commonRejectReasons = "common_reject_reasons"
    }
}

// MARK: - API Service

struct APIFailureClustering {
    let client: NetworkClientProtocol

    func getSummary() async throws -> FailureClusteringSummaryResponse {
        try await client.get("/api/growth/failure-summary", mock: MockFailureClustering.summary)
    }

    func getClusters() async throws -> FailureClusteringSummaryResponse {
        try await client.get("/api/growth/failure-clusters", mock: MockFailureClustering.summary)
    }

    func getLabels() async throws -> [String] {
        try await client.get("/api/growth/labels", mock: MockFailureClustering.labels)
    }
}

// MARK: - Mock

enum MockFailureClustering {
    static func summary() -> FailureClusteringSummaryResponse {
        FailureClusteringSummaryResponse(
            state: "warning",
            reasonCodes: ["high_failure_concentration"],
            availableActions: [
                AvailableActionResponse(type: "generate_fix_suggestions", enabled: true, label: "生成修复建议"),
            ],
            totalLossTrades: 23,
            totalLossAmount: -1847.50,
            clusters: [
                FailureClusterBFFResponse(clusterName: "entered_before_reclaim_confirmation", label: "未等确认即入场", tradeCount: 8, totalLoss: -680.20, avgLossPct: -0.012, exampleTradeIds: ["t-101", "t-115", "t-123"], suggestedFix: "要求 confirmed_sweep 状态后才允许入场 — 添加 reclaim 确认过滤器", severity: "high"),
                FailureClusterBFFResponse(clusterName: "stop_too_close_to_liquidity_pool", label: "止损过近流动性池", tradeCount: 5, totalLoss: -425.80, avgLossPct: -0.008, exampleTradeIds: ["t-108", "t-119"], suggestedFix: "增大 atr_buffer_coef（建议 0.5 代替 0.3）", severity: "high"),
                FailureClusterBFFResponse(clusterName: "failed_due_to_news_shock", label: "新闻冲击导致失败", tradeCount: 4, totalLoss: -380.50, avgLossPct: -0.015, exampleTradeIds: ["t-105", "t-130"], suggestedFix: "启用 slow_track_ai_cache_required=True", severity: "medium"),
                FailureClusterBFFResponse(clusterName: "failed_due_to_high_volatility", label: "高波动率下亏损", tradeCount: 3, totalLoss: -210.00, avgLossPct: -0.009, exampleTradeIds: ["t-112"], suggestedFix: "高波动 regime 下减仓 50%", severity: "medium"),
                FailureClusterBFFResponse(clusterName: "ai_cache_expired_reduced_size", label: "AI缓存过期被减仓", tradeCount: 3, totalLoss: -151.00, avgLossPct: -0.005, exampleTradeIds: ["t-128"], suggestedFix: "提高 AI cache 刷新频率或延长 TTL", severity: "low"),
            ],
            regimeMatrix: [
                RegimeFailureCellResponse(regime: "trend_up", failureType: "entered_before_reclaim", count: 3, totalLoss: -180.0),
                RegimeFailureCellResponse(regime: "range", failureType: "stop_too_close", count: 4, totalLoss: -320.0),
                RegimeFailureCellResponse(regime: "high_volatility", failureType: "news_shock", count: 3, totalLoss: -280.0),
                RegimeFailureCellResponse(regime: "panic", failureType: "high_volatility", count: 2, totalLoss: -150.0),
            ],
            commonRejectReasons: [
                ["code": "daily_loss_limit_reached", "count": "6"],
                ["code": "snapshot_stale", "count": "4"],
                ["code": "ai_cache_expired", "count": "3"],
            ],
            labels: ["entered_before_reclaim_confirmation", "stop_too_close_to_liquidity_pool", "failed_due_to_news_shock", "failed_due_to_high_volatility", "ai_cache_expired_reduced_size", "snapshot_disconnect_emergency_close"]
        )
    }

    static func labels() -> [String] {
        ["entered_before_reclaim_confirmation", "stop_too_close_to_liquidity_pool", "failed_due_to_news_shock", "failed_due_to_high_volatility", "ai_cache_expired_reduced_size", "snapshot_disconnect_emergency_close"]
    }
}
