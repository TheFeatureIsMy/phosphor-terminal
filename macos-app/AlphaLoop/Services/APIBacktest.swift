// APIBacktest.swift — 回测 API

import Foundation

struct APIBacktest {
    let client: NetworkClientProtocol

    @available(*, deprecated, message: "Pass strategyUuid + strategyVersionId UUID parameters; legacy int strategy_id is being phased out per spec §6.2.")
    func run(strategyId: Int, startDate: String, endDate: String, capital: Double, symbols: [String]) async throws -> Backtest {
        let body = ["strategy_id": strategyId, "start_date": startDate, "end_date": endDate, "initial_capital": capital, "symbols": symbols] as [String: Any]
        return try await client.post("/api/backtest", body: AnyEncodable(body), mock: MockData.mockBacktest)
    }

    /// UUID-based run (preferred). Sends both strategy_uuid + strategy_version_uuid.
    func run(
        strategyUuid: String,
        strategyVersionId: String,
        startDate: String,
        endDate: String,
        capital: Double,
        symbols: [String]
    ) async throws -> Backtest {
        let body: [String: Any] = [
            "strategy_uuid": strategyUuid,
            "strategy_version_uuid": strategyVersionId,
            "start_date": startDate,
            "end_date": endDate,
            "initial_capital": capital,
            "symbols": symbols,
        ]
        return try await client.post("/api/backtest", body: AnyEncodable(body), mock: MockData.mockBacktest)
    }

    func get(id: Int) async throws -> Backtest {
        try await client.get("/api/backtest/\(id)", mock: MockData.mockBacktest)
    }

    func list(
        strategyUuid: String? = nil,
        strategyVersionId: String? = nil,
        limit: Int = 20
    ) async throws -> [Backtest] {
        var path = "/api/backtest?limit=\(limit)"
        if let strategyUuid { path += "&strategy_uuid=\(strategyUuid)" }
        if let strategyVersionId { path += "&strategy_version_uuid=\(strategyVersionId)" }
        return try await client.get(path, mock: { [MockData.mockBacktest()] })
    }
}

// MARK: - AnyEncodable 包装器
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ value: Any) {
        encodeFunc = { encoder in
            var container = encoder.singleValueContainer()
            if let v = value as? String { try container.encode(v) }
            else if let v = value as? Int { try container.encode(v) }
            else if let v = value as? Double { try container.encode(v) }
            else if let v = value as? Bool { try container.encode(v) }
            else if let v = value as? [String: Any] { try container.encode(v.mapValues { AnyCodable($0) }) }
            else if let v = value as? [Any] { try container.encode(v.map { AnyCodable($0) }) }
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
