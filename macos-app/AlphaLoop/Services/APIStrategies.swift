// APIStrategies.swift - 策略 CRUD + 部署/停止

import Foundation

final class APIStrategies: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func list() async throws -> [Strategy] {
        try await client.get("/api/strategies")
    }

    func get(id: Int) async throws -> Strategy {
        try await client.get("/api/strategies/\(id)")
    }

    func create(name: String, market: String, exchange: String, tags: [String] = []) async throws -> Strategy {
        try await client.post("/api/strategies", body: ["name": name, "type": "ma_cross", "market": market, "exchange": exchange])
    }

    func delete(id: Int) async throws {
        try await client.delete("/api/strategies/\(id)")
    }

    func deploy(id: Int) async throws -> Strategy {
        try await client.post("/api/strategies/\(id)/deploy", body: nil)
    }

    func stop(id: Int) async throws -> Strategy {
        try await client.post("/api/strategies/\(id)/stop", body: nil)
    }

    func update(id: Int, name: String? = nil, market: String? = nil) async throws -> Strategy {
        struct UpdateBody: Encodable {
            let name: String?
            let market: String?
        }
        let body = UpdateBody(name: name, market: market)
        return try await client.put("/api/strategies/\(id)", body: body)
    }
}
