// APILiveSmall.swift - Live-Small pre-flight checks (precondition / evaluate / config preview / circuit breaker)

import Foundation

final class APILiveSmall: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func preconditionCheck(body: [String: Any]) async throws -> LiveSmallPrecondition {
        try await client.post("/api/live-small/precondition", body: AnyEncodable(body))
    }

    func evaluate(body: [String: Any]) async throws -> LiveSmallEvaluation {
        try await client.post("/api/live-small/evaluate", body: AnyEncodable(body))
    }

    func configPreview(body: [String: Any]) async throws -> [String: AnyCodable] {
        try await client.post("/api/live-small/config-preview", body: AnyEncodable(body))
    }

    func circuitBreakerCheck(body: [String: Any]) async throws -> [String: AnyCodable] {
        try await client.post("/api/live-small/circuit-breaker", body: AnyEncodable(body))
    }
}
