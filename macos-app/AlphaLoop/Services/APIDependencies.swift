// APIDependencies.swift — 依赖检测 API

import Foundation

struct DependencyResponse: Decodable {
    let required: [String: DependencyItem]
    let coreOptional: [String: DependencyItem]
    let mlModels: [String: DependencyItem]
    let externalServices: [String: DependencyItem]
    let readinessScore: Double
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case required
        case coreOptional = "core_optional"
        case mlModels = "ml_models"
        case externalServices = "external_services"
        case readinessScore = "readiness_score"
        case checkedAt = "checked_at"
    }
}

struct DependencyItem: Decodable {
    let status: String
    let version: String?
    let detail: String?
    let installCmd: String?
    let fallback: String?
    let url: String?
    let requires: String?

    enum CodingKeys: String, CodingKey {
        case status, version, detail, fallback, url, requires
        case installCmd = "install_cmd"
    }
}

struct APIDependencies {
    let client: NetworkClientProtocol

    func fetchDependencies() async throws -> DependencyResponse {
        try await client.get("/api/system/dependencies")
    }
}

