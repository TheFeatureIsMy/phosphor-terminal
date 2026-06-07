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

// MARK: - Routing Rules API

struct RoutingRuleResponse: Decodable {
    let taskType: String
    let primary: String
    let fallback: String
    let timeout: String
    let strategy: String

    enum CodingKeys: String, CodingKey {
        case primary, fallback, timeout, strategy
        case taskType = "task_type"
    }
}

struct RoutingRulesListResponse: Decodable {
    let rules: [RoutingRuleResponse]
}

// MARK: - Privacy Rules API

struct PrivacyRuleResponse: Decodable {
    let dataType: String
    let localAllowed: Bool
    let cloudAllowed: Bool
    let note: String

    enum CodingKeys: String, CodingKey {
        case note
        case dataType = "data_type"
        case localAllowed = "local_allowed"
        case cloudAllowed = "cloud_allowed"
    }
}

struct PrivacyRulesListResponse: Decodable {
    let rules: [PrivacyRuleResponse]
}

// MARK: - Model Runtime API

struct ModelRuntimeResponse: Decodable {
    let name: String
    let provider: String
    let state: String
    let modelId: String?
    let gpuMemoryMb: Int?

    enum CodingKeys: String, CodingKey {
        case name, provider, state
        case modelId = "model_id"
        case gpuMemoryMb = "gpu_memory_mb"
    }
}

struct ModelRuntimeListResponse: Decodable {
    let models: [ModelRuntimeResponse]
}

// MARK: - Extended API

extension APIAIProviders {
    func getRoutingRules() async throws -> [RoutingRuleResponse] {
        let resp: RoutingRulesListResponse = try await client.get("/api/ai/routing-rules", mock: {
            RoutingRulesListResponse(rules: [
                RoutingRuleResponse(taskType: "信号推理", primary: "Ollama", fallback: "DeepSeek", timeout: "30s", strategy: "failover"),
                RoutingRuleResponse(taskType: "情绪分析", primary: "FinBERT", fallback: "OpenAI", timeout: "15s", strategy: "local-only"),
                RoutingRuleResponse(taskType: "策略生成", primary: "DeepSeek", fallback: "OpenAI", timeout: "60s", strategy: "cost-opt"),
                RoutingRuleResponse(taskType: "研究报告", primary: "OpenAI", fallback: "DeepSeek", timeout: "120s", strategy: "round-robin"),
                RoutingRuleResponse(taskType: "风险评估", primary: "Ollama", fallback: "—", timeout: "10s", strategy: "local-only"),
            ])
        })
        return resp.rules
    }

    func getPrivacyRules() async throws -> [PrivacyRuleResponse] {
        let resp: PrivacyRulesListResponse = try await client.get("/api/ai/privacy-rules", mock: {
            PrivacyRulesListResponse(rules: [
                PrivacyRuleResponse(dataType: "交易信号", localAllowed: true, cloudAllowed: false, note: "仅本地推理"),
                PrivacyRuleResponse(dataType: "市场数据", localAllowed: true, cloudAllowed: true, note: "公开数据"),
                PrivacyRuleResponse(dataType: "持仓信息", localAllowed: true, cloudAllowed: false, note: "敏感数据"),
                PrivacyRuleResponse(dataType: "研究提示词", localAllowed: true, cloudAllowed: true, note: "可云端"),
                PrivacyRuleResponse(dataType: "策略 DSL", localAllowed: true, cloudAllowed: false, note: "核心 IP"),
                PrivacyRuleResponse(dataType: "新闻/情绪", localAllowed: true, cloudAllowed: true, note: "公开信息"),
            ])
        })
        return resp.rules
    }

    func getModelRuntime() async throws -> [ModelRuntimeResponse] {
        let resp: ModelRuntimeListResponse = try await client.get("/api/ai/models/runtime", mock: {
            ModelRuntimeListResponse(models: [
                ModelRuntimeResponse(name: "finbert", provider: "local-gpu", state: "running", modelId: "ProsusAI/finbert", gpuMemoryMb: 2048),
                ModelRuntimeResponse(name: "chronos", provider: "local-gpu", state: "available", modelId: "amazon/chronos-t5-tiny", gpuMemoryMb: nil),
                ModelRuntimeResponse(name: "shap", provider: "local-gpu", state: "running", modelId: "lightgbm+shap", gpuMemoryMb: nil),
            ])
        })
        return resp.models
    }
}
