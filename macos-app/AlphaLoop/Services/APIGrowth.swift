// APIGrowth.swift - Growth API (daily review, reports, candidates, SHAP, signal validity)

import Foundation

struct APIGrowth {
    let client: NetworkClientProtocol

    func runDailyReview(days: Int = 1) async throws -> GrowthReport {
        try await client.post("/api/growth/reports/daily-review", body: AnyEncodable(["days": days]))
    }

    func listReports(limit: Int = 20) async throws -> [GrowthReport] {
        try await client.get("/api/growth/reports?limit=\(limit)")
    }

    func listCandidates(limit: Int = 20) async throws -> [StrategyCandidate] {
        try await client.get("/api/growth/candidates?limit=\(limit)")
    }

    func confirmCandidate(_ id: String) async throws -> ConfirmCandidateResponse {
        try await client.post("/api/growth/candidates/\(id)/confirm", body: AnyEncodable([String: String]()))
    }

    func getShapFeatures() async throws -> ShapFeaturesResponse {
        try await client.get("/api/growth/shap-features")
    }

    func getSignalValidity() async throws -> SignalValidityResponse {
        try await client.get("/api/growth/signal-validity")
    }
}

// MARK: - Response Types

struct ShapFeatureItem: Codable {
    let name: String
    let value: Double
}

struct ShapFeaturesResponse: Codable {
    let state: String
    let features: [ShapFeatureItem]
}

struct SignalSourceItem: Codable {
    let name: String
    let accuracy: Double
    let total: Int
}

struct SignalValidityResponse: Codable {
    let state: String
    let sources: [SignalSourceItem]
}

struct ConfirmCandidateResponse: Codable {
    let strategyId: String
    let versionId: String
    let versionNo: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case status
        case strategyId = "strategy_id"
        case versionId = "version_id"
        case versionNo = "version_no"
    }
}
