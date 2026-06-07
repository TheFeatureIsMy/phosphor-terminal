// APISentiment.swift — 市场情绪 API

import Foundation

struct SentimentSummaryResponse: Decodable {
    let fearGreedIndex: Int
    let fearGreedLabel: String
    let marketOverview: [SymbolSentiment]
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case fearGreedIndex = "fear_greed_index"
        case fearGreedLabel = "fear_greed_label"
        case marketOverview = "market_overview"
        case updatedAt = "updated_at"
    }
}

struct SymbolSentiment: Decodable {
    let symbol: String
    let score: Double
    let sentiment: String
    let change24h: Double?

    enum CodingKeys: String, CodingKey {
        case symbol, score, sentiment
        case change24h = "change_24h"
    }
}

struct TextSentimentResponse: Decodable {
    let positive: Double
    let negative: Double
    let neutral: Double
}

struct SentimentTrendPoint: Decodable {
    let symbol: String
    let score: Double
    let sentiment: String
    let timestamp: String?
}

struct APISentiment {
    let client: any NetworkClientProtocol

    func getSummary() async throws -> SentimentSummaryResponse {
        try await client.get("/sentiment/summary", mock: {
            SentimentSummaryResponse(
                fearGreedIndex: 65,
                fearGreedLabel: "贪婪",
                marketOverview: [
                    SymbolSentiment(symbol: "BTC", score: 0.72, sentiment: "positive", change24h: 0.05),
                    SymbolSentiment(symbol: "ETH", score: 0.68, sentiment: "positive", change24h: 0.03),
                    SymbolSentiment(symbol: "SOL", score: 0.45, sentiment: "neutral", change24h: -0.02),
                ],
                updatedAt: "2026-05-31T12:00:00Z"
            )
        })
    }

    func getMarketSentiment(symbol: String, days: Int = 7) async throws -> [SentimentTrendPoint] {
        try await client.get("/sentiment/market/\(symbol)?days=\(days)", mock: { [] })
    }

    func analyzeText(_ text: String) async throws -> TextSentimentResponse {
        struct Body: Encodable { let text: String }
        return try await client.post("/sentiment/analyze", body: Body(text: text), mock: {
            TextSentimentResponse(positive: 0.6, negative: 0.1, neutral: 0.3)
        })
    }
}
