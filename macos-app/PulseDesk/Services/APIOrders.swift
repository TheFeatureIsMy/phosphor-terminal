// APIOrders.swift — 订单和持仓 API

import Foundation

struct APIOrders {
    let client: NetworkClientProtocol

    func listOrders(limit: Int = 50) async throws -> [Order] {
        try await client.get("/api/orders?limit=\(limit)", mock: { MockData.mockOrders(count: limit) })
    }

    func listPositions() async throws -> [Position] {
        try await client.get("/api/positions", mock: MockData.mockPositions)
    }
}
