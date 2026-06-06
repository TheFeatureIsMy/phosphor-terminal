// APIEmergency.swift — Emergency stop / resume operations

import Foundation

final class APIEmergency: @unchecked Sendable {
    let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - Emergency Stop

    func emergencyStop(strategyRunId: String? = nil, reason: String) async throws -> EmergencyStopResult {
        var body: [String: Any] = ["reason": reason]
        if let sid = strategyRunId { body["strategy_run_id"] = sid }
        return try await client.post("/api/v2/emergency/stop", body: AnyEncodable(body), mock: {
            EmergencyStopResult(
                stoppedRuns: strategyRunId != nil ? [strategyRunId!] : ["run-001", "run-003", "run-007"],
                message: strategyRunId != nil
                    ? "策略 \(strategyRunId!) 已紧急停止，2 个挂单已撤销，1 个持仓已市价平仓"
                    : "全局紧急停止已执行：3 个策略停止，11 个挂单已撤销，4 个持仓已市价平仓"
            )
        })
    }

    // MARK: - Emergency Resume

    func emergencyResume(strategyRunId: String, reason: String? = nil) async throws -> EmergencyStopResult {
        var body: [String: Any] = ["strategy_run_id": strategyRunId]
        if let r = reason { body["reason"] = r }
        return try await client.post("/api/v2/emergency/resume", body: AnyEncodable(body), mock: {
            EmergencyStopResult(
                stoppedRuns: [strategyRunId],
                message: "策略 \(strategyRunId) 已恢复运行"
            )
        })
    }
}
