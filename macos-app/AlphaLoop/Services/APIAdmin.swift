// APIAdmin.swift - Admin operations (data vacuum)

import Foundation

final class APIAdmin: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func runDataVacuum() async throws -> DataVacuumJob {
        try await client.post("/api/admin/data-vacuum", body: nil)
    }

    func listVacuumJobs(limit: Int = 10) async throws -> [DataVacuumJob] {
        try await client.get("/api/admin/data-vacuum?limit=\(limit)")
    }
}
