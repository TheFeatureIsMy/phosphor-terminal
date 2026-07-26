// APIEmergency.swift - Emergency stop / resume operations

import Foundation

final class APIEmergency: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func emergencyStop(strategyRunId: String? = nil, reason: String) async throws -> EmergencyStopResult {
        var body: [String: Any] = ["reason": reason]
        if let sid = strategyRunId { body["strategy_run_id"] = sid }
        return try await client.post("/api/v2/emergency/stop", body: AnyEncodable(body))
    }

    func emergencyResume(strategyRunId: String, reason: String? = nil) async throws -> EmergencyStopResult {
        var body: [String: Any] = ["strategy_run_id": strategyRunId]
        if let r = reason { body["reason"] = r }
        return try await client.post("/api/v2/emergency/resume", body: AnyEncodable(body))
    }
}
