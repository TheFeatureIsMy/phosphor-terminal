// APIInference.swift — Inference Job API (create / list / get / cancel / runtime state)

import Foundation

final class APIInference: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - Jobs

    func createJob(body: [String: Any]) async throws -> InferenceJob {
        let jobType = body["job_type"] as? String ?? "signal"
        let modelName = body["model_name"] as? String ?? "xgboost-signal-v3"
        return try await client.post("/api/v2/inference/jobs", body: AnyEncodable(body), mock: {
            InferenceJob(
                id: UUID().uuidString,
                jobType: jobType,
                modelName: modelName,
                status: "pending",
                submittedAt: ISO8601DateFormatter().string(from: Date()),
                startedAt: nil,
                completedAt: nil,
                errorMessage: nil,
                estimatedCostUsd: 0.12,
                actualCostUsd: nil
            )
        })
    }

    func listJobs(status: String? = nil, limit: Int = 20) async throws -> [InferenceJob] {
        var path = "/api/v2/inference/jobs?limit=\(limit)"
        if let s = status { path += "&status=\(s)" }
        return try await client.get(path, mock: { MockInferenceData.jobs() })
    }

    func getJob(id: String) async throws -> InferenceJob {
        try await client.get("/api/v2/inference/jobs/\(id)", mock: {
            MockInferenceData.jobs().first!
        })
    }

    func cancelJob(id: String) async throws -> InferenceJob {
        try await client.post("/api/v2/inference/jobs/\(id)/cancel", body: nil, mock: {
            InferenceJob(
                id: id,
                jobType: "signal",
                modelName: "xgboost-signal-v3",
                status: "cancelled",
                submittedAt: "2026-06-01T08:00:00Z",
                startedAt: "2026-06-01T08:00:05Z",
                completedAt: ISO8601DateFormatter().string(from: Date()),
                errorMessage: "Cancelled by user",
                estimatedCostUsd: 0.12,
                actualCostUsd: 0.04
            )
        })
    }

    // MARK: - Runtime State

    func getRuntimeState() async throws -> RuntimeStateInfo {
        try await client.get("/api/v2/inference/runtime", mock: {
            RuntimeStateInfo(
                modelName: "xgboost-signal-v3",
                provider: "local-gpu",
                state: "running",
                gpuMemoryMb: 6144,
                lastHeartbeatAt: ISO8601DateFormatter().string(from: Date())
            )
        })
    }
}

// MARK: - Mock data

enum MockInferenceData {
    static func jobs() -> [InferenceJob] {
        [
            InferenceJob(
                id: "inf-a1b2c3",
                jobType: "signal",
                modelName: "xgboost-signal-v3",
                status: "running",
                submittedAt: "2026-06-05T02:15:00Z",
                startedAt: "2026-06-05T02:15:05Z",
                completedAt: nil,
                errorMessage: nil,
                estimatedCostUsd: 0.15,
                actualCostUsd: nil
            ),
            InferenceJob(
                id: "inf-d4e5f6",
                jobType: "trend",
                modelName: "lstm-trend-v2",
                status: "completed",
                submittedAt: "2026-06-04T22:30:00Z",
                startedAt: "2026-06-04T22:30:03Z",
                completedAt: "2026-06-04T23:12:00Z",
                errorMessage: nil,
                estimatedCostUsd: 0.20,
                actualCostUsd: 0.18
            ),
            InferenceJob(
                id: "inf-g7h8i9",
                jobType: "alpha",
                modelName: "transformer-alpha-v1",
                status: "failed",
                submittedAt: "2026-06-04T18:00:00Z",
                startedAt: "2026-06-04T18:00:02Z",
                completedAt: "2026-06-04T18:22:00Z",
                errorMessage: "OOM: GPU memory exceeded 15.8GB limit",
                estimatedCostUsd: 0.50,
                actualCostUsd: 0.21
            ),
        ]
    }
}
