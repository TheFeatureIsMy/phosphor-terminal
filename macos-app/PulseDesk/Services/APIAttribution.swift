// APIAttribution.swift — 归因分析 API

import Foundation

// MARK: - Response Models

struct FeatureImportanceResponse: Decodable {
    let features: [String]
    let importances: [Double]
    let baseValue: Double?

    enum CodingKeys: String, CodingKey {
        case features, importances
        case baseValue = "base_value"
    }
}

struct SlippageItem: Decodable, Identifiable {
    let id: Int
    let tradeId: Int
    let signalPrice: Double
    let filledPrice: Double
    let executionSlippage: Double
    let spreadCost: Double
    let marketImpact: Double
    let latencyCost: Double
    let slippagePct: Double
    let diagnosis: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, diagnosis
        case tradeId = "trade_id"
        case signalPrice = "signal_price"
        case filledPrice = "filled_price"
        case executionSlippage = "execution_slippage"
        case spreadCost = "spread_cost"
        case marketImpact = "market_impact"
        case latencyCost = "latency_cost"
        case slippagePct = "slippage_pct"
        case createdAt = "created_at"
    }
}

struct AttributionReportItem: Decodable, Identifiable {
    let id: Int
    let tradeId: Int?
    let strategyId: Int?
    let featureContributions: [String: Double]?
    let topLossFactors: [String]?
    let summary: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, summary
        case tradeId = "trade_id"
        case strategyId = "strategy_id"
        case featureContributions = "feature_contributions"
        case topLossFactors = "top_loss_factors"
        case createdAt = "created_at"
    }
}

// MARK: - Attribution API

struct APIAttribution {
    let client: any NetworkClientProtocol

    func getFeatureImportance(features: [String], values: [Double]) async throws -> FeatureImportanceResponse {
        struct Body: Encodable {
            let features: [String]
            let values: [Double]
            let strategy_type: String
        }
        return try await client.post("/attribution/feature-importance", body: Body(features: features, values: values, strategy_type: "ma_cross"), mock: {
            FeatureImportanceResponse(
                features: ["RSI", "MACD", "Volume", "BB_Upper", "EMA_20"],
                importances: [0.35, 0.28, 0.18, 0.12, 0.07],
                baseValue: 0.05
            )
        })
    }

    func getSlippage() async throws -> [SlippageItem] {
        try await client.get("/attribution/slippage", mock: {
            [
                SlippageItem(
                    id: 1,
                    tradeId: 101,
                    signalPrice: 67500.0,
                    filledPrice: 67532.5,
                    executionSlippage: 32.5,
                    spreadCost: 12.0,
                    marketImpact: 8.5,
                    latencyCost: 12.0,
                    slippagePct: 0.048,
                    diagnosis: "spread_cost占比较高，建议使用限价单",
                    createdAt: "2026-05-31T10:00:00Z"
                ),
            ]
        })
    }

    func getReports(strategyId: Int? = nil) async throws -> [AttributionReportItem] {
        let endpoint = strategyId != nil ? "/attribution/reports?strategy_id=\(strategyId!)" : "/attribution/reports"
        return try await client.get(endpoint, mock: { [] })
    }
}
