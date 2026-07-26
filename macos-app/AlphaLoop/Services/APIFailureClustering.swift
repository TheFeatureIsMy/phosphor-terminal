// APIFailureClustering.swift - Failure Clustering BFF API

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
        try await client.get("/api/growth/failure-summary")
    }

    func getClusters() async throws -> FailureClusteringSummaryResponse {
        try await client.get("/api/growth/failure-clusters")
    }

    func getLabels() async throws -> [String] {
        try await client.get("/api/growth/labels")
    }
}
