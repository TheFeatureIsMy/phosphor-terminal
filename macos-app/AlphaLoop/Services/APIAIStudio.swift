// APIAIStudio.swift — AI Studio API services (RAG, Forecast, Factor, FreqAI)

import Foundation

// MARK: - Response Types

struct RAGGenerateResponse: Codable {
    let id: Int
    let code: String
    let safetyStatus: String
    let strategyName: String

    enum CodingKeys: String, CodingKey {
        case id, code
        case safetyStatus = "safety_status"
        case strategyName = "strategy_name"
    }
}

struct ForecastResponse: Codable {
    let id: Int
    let symbol: String
    let model: String
    let horizon: String
    let status: String
    let points: [[String: Double]]
    let confidence: Double?
}

struct FactorResearchResponse: Codable {
    let id: Int
    let market: String
    let factorName: String
    let status: String
    let metrics: [String: Double]

    enum CodingKeys: String, CodingKey {
        case id, market, status, metrics
        case factorName = "factor_name"
    }
}

struct FreqAITrainingResponse: Codable {
    let id: Int
    let modelName: String
    let status: String
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case modelName = "model_name"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct FreqAIRunsListResponse: Codable {
    let runs: [FreqAITrainingResponse]
    let total: Int
}

// MARK: - Request Bodies (file-scope to avoid generic nesting issues)

private struct RAGGenerateBody: Encodable {
    let prompt: String
    let risk_level: String
    let market: String
}

private struct ForecastBody: Encodable {
    let symbol: String
    let model: String
    let horizon: String
}

private struct FactorResearchBody: Encodable {
    let market: String
    let universe: [String]
    let factor_name: String
}

private struct FreqAITrainBody: Encodable {
    let model_name: String
    let strategy_id: Int?
}

// MARK: - NetworkClientProtocol Extensions

extension NetworkClientProtocol {
    func ragGenerate(prompt: String, riskLevel: String, market: String) async throws -> RAGGenerateResponse {
        try await post("/rag/generate", body: RAGGenerateBody(prompt: prompt, risk_level: riskLevel, market: market))
    }

    func createForecast(symbol: String, model: String, horizon: String) async throws -> ForecastResponse {
        try await post("/api/ai/forecast", body: ForecastBody(symbol: symbol, model: model, horizon: horizon))
    }

    func createFactorResearch(market: String, universe: [String], factorName: String) async throws -> FactorResearchResponse {
        try await post("/api/ai/factors/research", body: FactorResearchBody(market: market, universe: universe, factor_name: factorName))
    }

    func submitFreqAITraining(modelName: String, strategyId: Int?) async throws -> FreqAITrainingResponse {
        try await post("/api/ai/freqai/train", body: FreqAITrainBody(model_name: modelName, strategy_id: strategyId))
    }

    func listFreqAIRuns() async throws -> FreqAIRunsListResponse {
        try await get("/api/ai/freqai/runs")
    }
}
