// APIFailureClusters.swift — failure-clusters API service
// GET /api/growth/failure-clusters?strategy_uuid={uuid} → [FailureClusterSummary]

import Foundation

// MARK: - Response/DTO types

struct FailureClustersResponse: Decodable {
    let state: String
    let clusters: [FailureClusterDTO]
}

struct FailureClusterDTO: Decodable {
    let clusterName: String
    let tradeCount: Int
    let totalLoss: Double
    let avgLossPct: Double
    let exampleTradeIds: [String]
    let suggestedFix: String

    enum CodingKeys: String, CodingKey {
        case clusterName = "cluster_name"
        case tradeCount = "trade_count"
        case totalLoss = "total_loss"
        case avgLossPct = "avg_loss_pct"
        case exampleTradeIds = "example_trade_ids"
        case suggestedFix = "suggested_fix"
    }
}

// MARK: - NetworkClientProtocol extension

extension NetworkClientProtocol {

    func getFailureClusters(strategyUuid: UUID) async throws -> [FailureClusterSummary] {
        let resp: FailureClustersResponse = try await get(
            "/api/growth/failure-clusters?strategy_uuid=\(strategyUuid)"
        ) {
            FailureClustersResponse(state: "empty", clusters: [])
        }
        return resp.clusters.map {
            FailureClusterSummary(
                id: $0.clusterName,
                label: $0.clusterName,
                sampleSize: $0.tradeCount,
                totalLoss: $0.totalLoss,
                avgLoss: $0.avgLossPct,
                commonFeatures: $0.suggestedFix.split(separator: ";").map(String.init)
            )
        }
    }
}
