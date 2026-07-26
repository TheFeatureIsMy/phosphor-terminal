// APIInference.swift - Inference Job API (create / list / get / cancel / runtime state)

import Foundation

final class APIInference: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func createJob(body: [String: Any]) async throws -> InferenceJob {
        try await client.post("/api/inference/jobs", body: AnyEncodable(body))
    }

    func listJobs(status: String? = nil, limit: Int = 20) async throws -> [InferenceJob] {
        var path = "/api/inference/jobs?limit=\(limit)"
        if let s = status { path += "&status=\(s)" }
        return try await client.get(path)
    }

    func getJob(id: String) async throws -> InferenceJob {
        try await client.get("/api/inference/jobs/\(id)")
    }

    func cancelJob(id: String) async throws -> InferenceJob {
        try await client.post("/api/inference/jobs/\(id)/cancel", body: nil)
    }

    func getRuntimeState() async throws -> RuntimeStateInfo {
        try await client.get("/api/inference/runtime")
    }
}
