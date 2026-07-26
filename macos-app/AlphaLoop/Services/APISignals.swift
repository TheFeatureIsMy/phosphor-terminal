// APISignals.swift — Agent 信号 API 服务

import Foundation

extension NetworkClientProtocol {
    func listAgentSignals() async throws -> [AgentSignal] {
        try await get("/api/agent-signals/signals")
    }

    func listAgentProfiles() async throws -> [AgentProfile] {
        try await get("/api/agent-signals/agents")
    }
}

