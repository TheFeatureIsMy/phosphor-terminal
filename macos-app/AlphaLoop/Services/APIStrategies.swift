// APIStrategies.swift — 策略 CRUD + 部署/停止
// Mock 模式下维护内存数组，支持会话内持久化 CRUD

import Foundation

final class APIStrategies: @unchecked Sendable {
    let client: NetworkClientProtocol
    // Mock 模式下的内存策略列表
    private var mockStrategies: [Strategy] = MockData.mockStrategies()

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func list() async throws -> [Strategy] {
        try await client.get("/api/strategies", mock: { [self] in mockStrategies })
    }

    func get(id: Int) async throws -> Strategy {
        try await client.get("/api/strategies/\(id)", mock: { [self] in
            mockStrategies.first { $0.id == id } ?? mockStrategies[0]
        })
    }

    func create(name: String, market: String, exchange: String, tags: [String] = []) async throws -> Strategy {
        try await client.post("/api/strategies", body: ["name": name, "type": "ma_cross", "market": market, "exchange": exchange], mock: { [self] in
            let newId = (mockStrategies.map(\.id).max() ?? 0) + 1
            let strategy = Strategy(
                id: newId, userId: 1, name: name,
                parameters: [:], source: .manual, market: market, exchange: exchange,
                version: 1, status: .draft, sharpeRatio: nil, maxDrawdown: nil,
                tags: tags,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            mockStrategies.insert(strategy, at: 0)
            return strategy
        })
    }

    func delete(id: Int) async throws {
        try await client.delete("/api/strategies/\(id)", mock: { [self] in
            mockStrategies.removeAll { $0.id == id }
        })
    }

    func deploy(id: Int) async throws -> Strategy {
        try await client.post("/api/strategies/\(id)/deploy", body: nil as String?, mock: { [self] in
            if let index = mockStrategies.firstIndex(where: { $0.id == id }) {
                mockStrategies[index].status = .active
            }
            return mockStrategies.first { $0.id == id } ?? mockStrategies[0]
        })
    }

    func stop(id: Int) async throws -> Strategy {
        try await client.post("/api/strategies/\(id)/stop", body: nil as String?, mock: { [self] in
            if let index = mockStrategies.firstIndex(where: { $0.id == id }) {
                mockStrategies[index].status = .paused
            }
            return mockStrategies.first { $0.id == id } ?? mockStrategies[0]
        })
    }

    func update(id: Int, name: String? = nil, market: String? = nil) async throws -> Strategy {
        struct UpdateBody: Encodable {
            let name: String?
            let market: String?
        }
        let body = UpdateBody(name: name, market: market)
        return try await client.put("/api/strategies/\(id)", body: body, mock: { MockData.mockStrategies().first! })
    }
}
