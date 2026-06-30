// APIResearch.swift — AI 研究 API 服务

import Foundation

private struct CreateResearchRequest: Encodable {
    let symbol: String
    let asset_type: String
    let analysis_date: String
    let selected_analysts: [String]
    let llm_provider: String
}

extension NetworkClientProtocol {
    func listResearchRuns() async throws -> [AIResearchRun] {
        try await get("/api/ai-research/runs", mock: MockResearch.runs)
    }

    func createResearchRun(symbol: String, assetType: String) async throws -> AIResearchRun {
        let body = CreateResearchRequest(
            symbol: symbol, asset_type: assetType,
            analysis_date: "2026-05-28",
            selected_analysts: ["market", "social", "news", "fundamentals"],
            llm_provider: "openai"
        )
        return try await post("/api/ai-research/runs", body: body,
            mock: { MockResearch.pending(symbol: symbol, assetType: assetType) })
    }
}

enum MockResearch {
    static func runs() -> [AIResearchRun] {
        [
            AIResearchRun(
                id: 1, symbol: "BTC/USDT", assetType: "crypto",
                analysisDate: "2026-05-28", provider: "tradingagents",
                status: "completed", rating: "Overweight",
                finalDecision: "**评级**: Overweight\n\nAI 研究委员会认为当前技术面和基本面均支持看多，但需关注宏观风险。建议轻仓介入，设置止损。",
                marketReport: "技术面：BTC 在 68000-72000 区间震荡，MACD 金叉，RSI 55 中性偏多。",
                sentimentReport: "社交媒体情绪偏正面，恐惧贪婪指数 65（贪婪）。",
                newsReport: "近期 ETF 持续净流入，机构兴趣增加。",
                fundamentalsReport: "链上活跃地址数上升，长期持有者占比稳定。",
                errorMessage: nil, createdAt: "2026-05-28T10:30:00Z"
            ),
            AIResearchRun(
                id: 2, symbol: "NVDA", assetType: "stock",
                analysisDate: "2026-05-28", provider: "tradingagents",
                status: "completed", rating: "Buy",
                finalDecision: "**评级**: Buy\n\nAI 芯片需求持续增长，NVDA 数据中心业务表现强劲。",
                marketReport: "股价突破前高，成交量放大。",
                sentimentReport: "分析师一致看多。",
                newsReport: "新产品发布推动市场预期。",
                fundamentalsReport: "营收同比增长 80%，利润率持续扩大。",
                errorMessage: nil, createdAt: "2026-05-27T14:20:00Z"
            ),
        ]
    }

    static func pending(symbol: String, assetType: String) -> AIResearchRun {
        AIResearchRun(
            id: Int.random(in: 100...999), symbol: symbol, assetType: assetType,
            analysisDate: "2026-05-28", provider: "tradingagents",
            status: "pending", rating: nil, finalDecision: nil,
            marketReport: nil, sentimentReport: nil, newsReport: nil,
            fundamentalsReport: nil, errorMessage: nil,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
