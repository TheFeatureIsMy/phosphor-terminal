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
        try await client.get("/api/system/dependencies", mock: {
            DependencyResponse(
                required: [
                    "database": DependencyItem(
                        status: "ok", version: nil, detail: "SQLite",
                        installCmd: nil, fallback: nil, url: nil, requires: nil
                    ),
                    "python": DependencyItem(
                        status: "ok", version: "3.11.0", detail: nil,
                        installCmd: nil, fallback: nil, url: nil, requires: nil
                    ),
                ],
                coreOptional: [
                    "redis": DependencyItem(
                        status: "missing", version: nil, detail: "Used for caching",
                        installCmd: "brew install redis", fallback: "in-memory cache", url: nil, requires: nil
                    ),
                ],
                mlModels: [
                    "finbert": DependencyItem(
                        status: "loaded", version: "1.0", detail: "FinBERT sentiment model",
                        installCmd: nil, fallback: "keyword-based", url: nil, requires: nil
                    ),
                ],
                externalServices: [
                    "freqtrade": DependencyItem(
                        status: "connected", version: nil, detail: "http://localhost:8080",
                        installCmd: nil, fallback: nil, url: "http://localhost:8080", requires: nil
                    ),
                ],
                readinessScore: 0.75,
                checkedAt: ISO8601DateFormatter().string(from: Date())
            )
        })
    }
}
