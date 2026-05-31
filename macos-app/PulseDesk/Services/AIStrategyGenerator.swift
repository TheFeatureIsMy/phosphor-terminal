import Foundation

struct AIGenerateRequest: Encodable {
    let prompt: String
}

struct AIGenerateResponse: Decodable {
    let strategy_id: Int
    let name: String
    let market: String
    let exchange: String
    let graph_json: String

    var graph: WorkflowGraph? {
        guard let data = graph_json.data(using: .utf8) else { return nil }
        return try? GraphSerializer().deserialize(data)
    }
}

struct AIStrategyGenerator {
    let client: any NetworkClientProtocol

    func generate(prompt: String) async throws -> AIGenerateResponse {
        try await client.post("/api/strategies/generate", body: AIGenerateRequest(prompt: prompt), mock: {
            AIGenerateResponse(
                strategy_id: 999,
                name: "AI 生成策略",
                market: "crypto",
                exchange: "binance",
                graph_json: "{\"nodes\":[],\"edges\":[],\"groups\":[],\"viewport\":{\"scale\":1.0,\"offset\":{\"x\":0,\"y\":0}}}"
            )
        })
    }
}
