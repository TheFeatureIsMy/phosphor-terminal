// APICanvas.swift — Canvas workflow persistence API

import Foundation

struct CanvasSaveResponse: Decodable {
    let id: String
    let strategyId: Int
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case strategyId = "strategy_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CanvasLoadResponse: Decodable {
    let id: String
    let strategyId: Int
    let graphJson: String
    let codeSnapshot: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case strategyId = "strategy_id"
        case graphJson = "graph_json"
        case codeSnapshot = "code_snapshot"
        case updatedAt = "updated_at"
    }
}

struct APICanvas {
    let client: any NetworkClientProtocol

    func save(strategyId: Int, graphJson: String, codeSnapshot: String? = nil) async throws -> CanvasSaveResponse {
        struct Body: Encodable {
            let graph_json: String
            let code_snapshot: String?
        }
        return try await client.post("/api/strategies/\(strategyId)/canvas", body: Body(graph_json: graphJson, code_snapshot: codeSnapshot), mock: {
            CanvasSaveResponse(id: "mock-1", strategyId: strategyId, createdAt: nil, updatedAt: ISO8601DateFormatter().string(from: Date()))
        })
    }

    func load(strategyId: Int) async throws -> CanvasLoadResponse {
        try await client.get("/api/strategies/\(strategyId)/canvas", mock: {
            CanvasLoadResponse(id: "mock-1", strategyId: strategyId, graphJson: "{}", codeSnapshot: nil, updatedAt: nil)
        })
    }

    func update(strategyId: Int, graphJson: String, codeSnapshot: String? = nil) async throws -> CanvasSaveResponse {
        struct Body: Encodable {
            let graph_json: String
            let code_snapshot: String?
        }
        return try await client.put("/api/strategies/\(strategyId)/canvas", body: Body(graph_json: graphJson, code_snapshot: codeSnapshot), mock: {
            CanvasSaveResponse(id: "mock-1", strategyId: strategyId, createdAt: nil, updatedAt: ISO8601DateFormatter().string(from: Date()))
        })
    }
}
