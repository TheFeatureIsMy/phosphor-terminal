// APIAIProviders.swift — AI Provider 管理 API

import Foundation

struct AIProviderInfo: Decodable, Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let baseUrl: String?
    let isAvailable: Bool
    let modelCount: Int?

    enum CodingKeys: String, CodingKey {
        case name, type
        case baseUrl = "base_url"
        case isAvailable = "is_available"
        case modelCount = "model_count"
    }
}

struct ModelStatusInfo: Decodable, Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let fallback: String?

    enum CodingKeys: String, CodingKey {
        case name, status, fallback
    }
}

struct AIProvidersListResponse: Decodable {
    let providers: [AIProviderInfo]
}

struct ModelStatusResponse: Decodable {
    let models: [String: ModelStatusInfo]
}

struct TestProviderResponse: Decodable {
    let success: Bool
    let message: String
    let models: [String]?
}

struct APIAIProviders {
    let client: any NetworkClientProtocol

    func listProviders() async throws -> [AIProviderInfo] {
        try await client.get("/api/ai/providers", mock: {
            [
                AIProviderInfo(name: "Ollama", type: "ollama", baseUrl: "http://localhost:11434", isAvailable: true, modelCount: 3),
                AIProviderInfo(name: "OpenAI", type: "openai", baseUrl: "https://api.openai.com/v1", isAvailable: false, modelCount: nil),
                AIProviderInfo(name: "DeepSeek", type: "openai_compatible", baseUrl: "https://api.deepseek.com/v1", isAvailable: false, modelCount: nil),
            ]
        })
    }

    func getModelStatus() async throws -> [String: ModelStatusInfo] {
        struct Response: Decodable { let finbert: ModelStatusInfo?; let chronos: ModelStatusInfo?; let timesfm: ModelStatusInfo?; let shap: ModelStatusInfo? }
        let resp: Response = try await client.get("/api/ai/models/status", mock: {
            Response(
                finbert: ModelStatusInfo(name: "FinBERT", status: "loaded", fallback: "keyword_sentiment"),
                chronos: ModelStatusInfo(name: "Chronos", status: "not_loaded", fallback: "unavailable"),
                timesfm: ModelStatusInfo(name: "TimesFM", status: "not_loaded", fallback: "unavailable"),
                shap: ModelStatusInfo(name: "SHAP", status: "loaded", fallback: nil)
            )
        })
        var result: [String: ModelStatusInfo] = [:]
        if let f = resp.finbert { result["finbert"] = f }
        if let c = resp.chronos { result["chronos"] = c }
        if let t = resp.timesfm { result["timesfm"] = t }
        if let s = resp.shap { result["shap"] = s }
        return result
    }

    func testProvider(name: String) async throws -> TestProviderResponse {
        struct Body: Encodable { let provider: String }
        return try await client.post("/api/ai/providers/test", body: Body(provider: name), mock: {
            TestProviderResponse(success: true, message: "连接成功", models: ["qwen2.5:7b", "llama3:8b"])
        })
    }

    func preloadModels() async throws {
        struct Empty: Decodable {}
        _ = try await client.post("/api/ai/models/preload", body: nil as String?, mock: { Empty() })
    }
}
