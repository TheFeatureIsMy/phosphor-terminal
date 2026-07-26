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
        try await get("/api/ai-research/runs")
    }

    func createResearchRun(symbol: String, assetType: String) async throws -> AIResearchRun {
        let body = CreateResearchRequest(
            symbol: symbol, asset_type: assetType,
            analysis_date: "2026-05-28",
            selected_analysts: ["market", "social", "news", "fundamentals"],
            llm_provider: "openai"
        )
        return try await post("/api/ai-research/runs", body: body)
    }
}

