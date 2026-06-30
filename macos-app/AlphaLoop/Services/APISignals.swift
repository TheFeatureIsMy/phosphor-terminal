// APISignals.swift — Agent 信号 API 服务

import Foundation

extension NetworkClientProtocol {
    func listAgentSignals() async throws -> [AgentSignal] {
        try await get("/api/agent-signals/signals", mock: MockSignals.agentSignals)
    }

    func listAgentProfiles() async throws -> [AgentProfile] {
        try await get("/api/agent-signals/agents", mock: MockSignals.agentProfiles)
    }
}

enum MockSignals {
    static func agentSignals() -> [AgentSignal] {
        [
            AgentSignal(
                id: 1, agentId: 1, source: "tradingagents", messageType: "research",
                symbol: "BTC/USDT", market: "crypto", direction: "long",
                rating: "Overweight", confidence: 0.72, targetPrice: 75000,
                stopLoss: 65000, content: "BTC 技术面看多，建议轻仓做多。目标 75000，止损 65000。",
                overallScore: 3.8, createdAt: "2026-05-28T10:35:00Z"
            ),
            AgentSignal(
                id: 2, agentId: 1, source: "tradingagents", messageType: "research",
                symbol: "ETH/USDT", market: "crypto", direction: "long",
                rating: "Buy", confidence: 0.68, targetPrice: 4200,
                stopLoss: 3500, content: "ETH 生态活跃度上升，DeFi TVL 增长。",
                overallScore: 3.5, createdAt: "2026-05-27T16:00:00Z"
            ),
            AgentSignal(
                id: 3, agentId: 2, source: "manual", messageType: "strategy",
                symbol: "SOL/USDT", market: "crypto", direction: "short",
                rating: "Sell", confidence: 0.55, targetPrice: 120,
                stopLoss: 180, content: "SOL 短期超买，建议逢高做空。",
                overallScore: 2.9, createdAt: "2026-05-26T09:15:00Z"
            ),
        ]
    }

    static func agentProfiles() -> [AgentProfile] {
        [
            AgentProfile(
                id: 1, name: "AI Research Committee", kind: "research",
                status: "active", description: "TradingAgents 多智能体研究委员会",
                lastHeartbeatAt: "2026-05-28T10:35:00Z",
                createdAt: "2026-05-20T00:00:00Z", updatedAt: "2026-05-28T10:35:00Z"
            ),
            AgentProfile(
                id: 2, name: "Manual Analyst", kind: "manual",
                status: "active", description: "人工分析信号",
                lastHeartbeatAt: nil,
                createdAt: "2026-05-15T00:00:00Z", updatedAt: "2026-05-15T00:00:00Z"
            ),
        ]
    }
}
