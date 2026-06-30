// APIAIProviders.swift — AI Provider 管理 API

import Foundation

// MARK: - Provider Config View Model (backend /api/admin/providers response)

struct ProviderConfigView: Codable, Identifiable {
    let id: Int
    let category: String
    let providerName: String
    let instanceName: String?
    let enabled: Bool
    let isActive: Bool
    let priority: Int
    let status: String
    let credentialStatus: String
    let credentialsFields: [String]
    let lastSyncAt: Date?
    let lastError: String?
    let latencyMs: Int?
    let rateLimitRemaining: Int?
    let rateLimitResetAt: Date?
    let config: [String: AnyCodable]
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, category, config
        case providerName = "provider_name"
        case instanceName = "instance_name"
        case enabled, priority, status
        case isActive = "is_active"
        case credentialStatus = "credential_status"
        case credentialsFields = "credentials_fields"
        case lastSyncAt = "last_sync_at"
        case lastError = "last_error"
        case latencyMs = "latency_ms"
        case rateLimitRemaining = "rate_limit_remaining"
        case rateLimitResetAt = "rate_limit_reset_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Request Bodies

struct ProviderConfigPayload: Encodable {
    let category: String
    let providerName: String
    let instanceName: String?
    let enabled: Bool
    let priority: Int
    let config: [String: String]
    let credentials: [String: String]?

    enum CodingKeys: String, CodingKey {
        case category, enabled, priority, config, credentials
        case providerName = "provider_name"
        case instanceName = "instance_name"
    }
}

struct ProviderTestRequestBody: Encodable {
    let category: String
    let providerName: String
    let credentials: [String: String]
    let config: [String: String]

    enum CodingKeys: String, CodingKey {
        case category, credentials, config
        case providerName = "provider_name"
    }
}

// MARK: - Health Check Result

struct HealthCheckResultResponse: Decodable {
    let success: Bool
    let status: String
    let latencyMs: Int?
    let error: String?
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case success, status
        case latencyMs = "latency_ms"
        case error
        case checkedAt = "checked_at"
    }
}

// MARK: - Legacy Types (view compatibility)

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

struct TestProviderResponse: Decodable {
    let success: Bool
    let message: String
    let models: [String]?
}

// MARK: - API Service

struct APIAIProviders {
    let client: any NetworkClientProtocol

    // MARK: New admin providers API

    /// GET /api/admin/providers?category=llm → [ProviderConfigView]
    func listProviders() async throws -> [ProviderConfigView] {
        try await client.get("/api/admin/providers?category=llm", mock: MockAIProviders.providers)
    }

    /// POST /api/admin/providers → ProviderConfigView
    func updateConfig(body: ProviderConfigPayload) async throws -> ProviderConfigView {
        try await client.post("/api/admin/providers", body: body,
            mock: { MockAIProviders.config(body: body) })
    }

    /// POST /api/admin/providers/test (ephemeral) → HealthCheckResultResponse
    func testConnection(body: ProviderTestRequestBody) async throws -> HealthCheckResultResponse {
        try await client.post("/api/admin/providers/test", body: body,
            mock: { MockAIProviders.healthCheck })
    }

    // MARK: Legacy API (unchanged)

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
        return try await client.post("/api/ai/providers/test", body: Body(provider: name),
            mock: { MockAIProviders.testProvider })
    }

    func preloadModels() async throws {
        struct Empty: Decodable {}
        _ = try await client.post("/api/ai/models/preload", body: nil as String?,
            mock: { Empty() })
    }
}

enum MockAIProviders {
    static func providers() -> [ProviderConfigView] {
        [
            ProviderConfigView(id: 1, category: "llm", providerName: "Ollama", instanceName: "default", enabled: true, isActive: true, priority: 0, status: "active", credentialStatus: "configured", credentialsFields: [], lastSyncAt: Date(), lastError: nil, latencyMs: 12, rateLimitRemaining: nil, rateLimitResetAt: nil, config: ["base_url": AnyCodable("http://localhost:11434")], updatedAt: Date()),
            ProviderConfigView(id: 2, category: "llm", providerName: "OpenAI", instanceName: "default", enabled: true, isActive: false, priority: 1, status: "error", credentialStatus: "missing", credentialsFields: ["api_key"], lastSyncAt: nil, lastError: "API key not configured", latencyMs: nil, rateLimitRemaining: nil, rateLimitResetAt: nil, config: [:], updatedAt: Date()),
            ProviderConfigView(id: 3, category: "llm", providerName: "DeepSeek", instanceName: "default", enabled: true, isActive: false, priority: 2, status: "unknown", credentialStatus: "missing", credentialsFields: ["api_key"], lastSyncAt: nil, lastError: nil, latencyMs: nil, rateLimitRemaining: nil, rateLimitResetAt: nil, config: [:], updatedAt: Date()),
        ]
    }

    static func config(body: ProviderConfigPayload) -> ProviderConfigView {
        ProviderConfigView(id: 0, category: body.category, providerName: body.providerName, instanceName: body.instanceName, enabled: body.enabled, isActive: false, priority: body.priority, status: "unknown", credentialStatus: body.credentials != nil ? "configured" : "missing", credentialsFields: body.credentials?.map(\.key) ?? [], lastSyncAt: nil, lastError: nil, latencyMs: nil, rateLimitRemaining: nil, rateLimitResetAt: nil, config: [:], updatedAt: Date())
    }

    static var healthCheck: HealthCheckResultResponse {
        HealthCheckResultResponse(success: true, status: "active", latencyMs: 42, error: nil, checkedAt: ISO8601DateFormatter().string(from: Date()))
    }

    static var testProvider: TestProviderResponse {
        TestProviderResponse(success: true, message: "连接成功", models: ["qwen2.5:7b", "llama3:8b"])
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
        let resp: RoutingRulesListResponse = try await client.get("/api/ai/routing-rules",
            mock: MockAIProviders.routingRulesResponse)
        return resp.rules
    }

    func getPrivacyRules() async throws -> [PrivacyRuleResponse] {
        let resp: PrivacyRulesListResponse = try await client.get("/api/ai/privacy-rules",
            mock: MockAIProviders.privacyRulesResponse)
        return resp.rules
    }

    func getModelRuntime() async throws -> [ModelRuntimeResponse] {
        let resp: ModelRuntimeListResponse = try await client.get("/api/ai/models/runtime",
            mock: MockAIProviders.modelRuntimeResponse)
        return resp.models
    }
}

extension MockAIProviders {
    static func routingRulesResponse() -> RoutingRulesListResponse {
        RoutingRulesListResponse(rules: [
            RoutingRuleResponse(taskType: "信号推理", primary: "Ollama", fallback: "DeepSeek", timeout: "30s", strategy: "failover"),
            RoutingRuleResponse(taskType: "情绪分析", primary: "FinBERT", fallback: "OpenAI", timeout: "15s", strategy: "local-only"),
            RoutingRuleResponse(taskType: "策略生成", primary: "DeepSeek", fallback: "OpenAI", timeout: "60s", strategy: "cost-opt"),
            RoutingRuleResponse(taskType: "研究报告", primary: "OpenAI", fallback: "DeepSeek", timeout: "120s", strategy: "round-robin"),
            RoutingRuleResponse(taskType: "风险评估", primary: "Ollama", fallback: "—", timeout: "10s", strategy: "local-only"),
        ])
    }

    static func privacyRulesResponse() -> PrivacyRulesListResponse {
        PrivacyRulesListResponse(rules: [
            PrivacyRuleResponse(dataType: "交易信号", localAllowed: true, cloudAllowed: false, note: "仅本地推理"),
            PrivacyRuleResponse(dataType: "市场数据", localAllowed: true, cloudAllowed: true, note: "公开数据"),
            PrivacyRuleResponse(dataType: "持仓信息", localAllowed: true, cloudAllowed: false, note: "敏感数据"),
            PrivacyRuleResponse(dataType: "研究提示词", localAllowed: true, cloudAllowed: true, note: "可云端"),
            PrivacyRuleResponse(dataType: "策略 DSL", localAllowed: true, cloudAllowed: false, note: "核心 IP"),
            PrivacyRuleResponse(dataType: "新闻/情绪", localAllowed: true, cloudAllowed: true, note: "公开信息"),
        ])
    }

    static func modelRuntimeResponse() -> ModelRuntimeListResponse {
        ModelRuntimeListResponse(models: [
            ModelRuntimeResponse(name: "finbert", provider: "local-gpu", state: "running", modelId: "ProsusAI/finbert", gpuMemoryMb: 2048),
            ModelRuntimeResponse(name: "chronos", provider: "local-gpu", state: "available", modelId: "amazon/chronos-t5-tiny", gpuMemoryMb: nil),
            ModelRuntimeResponse(name: "shap", provider: "local-gpu", state: "running", modelId: "lightgbm+shap", gpuMemoryMb: nil),
        ])
    }
}
