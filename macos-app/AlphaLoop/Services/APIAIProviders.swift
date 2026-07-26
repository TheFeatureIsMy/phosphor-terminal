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
        try await client.get("/api/admin/providers?category=llm")
    }

    /// POST /api/admin/providers → ProviderConfigView
    func updateConfig(body: ProviderConfigPayload) async throws -> ProviderConfigView {
        try await client.post("/api/admin/providers", body: body)
    }

    /// POST /api/admin/providers/test (ephemeral) → HealthCheckResultResponse
    func testConnection(body: ProviderTestRequestBody) async throws -> HealthCheckResultResponse {
        try await client.post("/api/admin/providers/test", body: body)
    }

    // MARK: Legacy API (unchanged)

    func getModelStatus() async throws -> [String: ModelStatusInfo] {
        struct Response: Decodable { let finbert: ModelStatusInfo?; let chronos: ModelStatusInfo?; let timesfm: ModelStatusInfo?; let shap: ModelStatusInfo? }
        let resp: Response = try await client.get("/api/ai/models/status")
        var result: [String: ModelStatusInfo] = [:]
        if let f = resp.finbert { result["finbert"] = f }
        if let c = resp.chronos { result["chronos"] = c }
        if let t = resp.timesfm { result["timesfm"] = t }
        if let s = resp.shap { result["shap"] = s }
        return result
    }

    func testProvider(name: String) async throws -> TestProviderResponse {
        struct Body: Encodable { let provider: String }
        return try await client.post("/api/ai/providers/test", body: Body(provider: name))
    }

    func preloadModels() async throws {
        struct Empty: Decodable {}
        struct NoBody: Encodable {}
        let result: Empty = try await client.post("/api/ai/models/preload", body: NoBody())
        _ = result
    }
}

// MARK: - Routing Rules

struct RoutingRuleResponse: Decodable, Identifiable {
    var id: String { taskType }
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

// MARK: - Privacy Rules

struct PrivacyRuleResponse: Decodable, Identifiable {
    var id: String { dataType }
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

// MARK: - Model Runtime

struct ModelRuntimeResponse: Decodable, Identifiable {
    var id: String { name }
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
        let resp: RoutingRulesListResponse = try await client.get("/api/ai/routing-rules")
        return resp.rules
    }

    func getPrivacyRules() async throws -> [PrivacyRuleResponse] {
        let resp: PrivacyRulesListResponse = try await client.get("/api/ai/privacy-rules")
        return resp.rules
    }

    func getModelRuntime() async throws -> [ModelRuntimeResponse] {
        let resp: ModelRuntimeListResponse = try await client.get("/api/ai/models/runtime")
        return resp.models
    }
}
