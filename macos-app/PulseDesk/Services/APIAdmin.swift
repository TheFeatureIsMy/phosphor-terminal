// APIAdmin.swift — Admin operations (data vacuum)

import Foundation

final class APIAdmin: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - Data Vacuum

    func runDataVacuum() async throws -> DataVacuumJob {
        try await client.post("/api/v2/admin/vacuum", body: nil, mock: {
            DataVacuumJob(
                id: UUID().uuidString,
                status: "running",
                signalsScanned: 0,
                signalsArchived: 0,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        })
    }

    func listVacuumJobs(limit: Int = 10) async throws -> [DataVacuumJob] {
        try await client.get("/api/v2/admin/vacuum?limit=\(limit)", mock: {
            MockAdminData.vacuumJobs()
        })
    }
}

// MARK: - Mock data

enum MockAdminData {
    static func vacuumJobs() -> [DataVacuumJob] {
        [
            DataVacuumJob(
                id: "vac-001",
                status: "completed",
                signalsScanned: 48_210,
                signalsArchived: 12_053,
                createdAt: "2026-06-05T02:00:00Z"
            ),
            DataVacuumJob(
                id: "vac-002",
                status: "completed",
                signalsScanned: 31_455,
                signalsArchived: 7_864,
                createdAt: "2026-06-04T02:00:00Z"
            ),
            DataVacuumJob(
                id: "vac-003",
                status: "failed",
                signalsScanned: 8_120,
                signalsArchived: 2_030,
                createdAt: "2026-06-03T02:00:00Z"
            ),
        ]
    }
}
