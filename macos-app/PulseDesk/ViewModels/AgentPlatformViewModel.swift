// AgentPlatformViewModel.swift — Agent 平台视图模型
// 加载 Agent 配置文件及其最近信号

import SwiftUI

@Observable
@MainActor
final class AgentPlatformViewModel {
    var agents: [AgentProfile] = []
    var signalsByAgent: [Int: [AgentSignal]] = [:]
    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    // MARK: - 加载数据

    func loadAll() async {
        isLoading = true
        error = nil
        do {
            async let agentsTask = client.listAgentProfiles()
            async let signalsTask = client.listAgentSignals()

            agents = try await agentsTask
            let allSignals = try await signalsTask

            // 按 agent 分组信号
            var grouped: [Int: [AgentSignal]] = [:]
            for signal in allSignals {
                grouped[signal.agentId, default: []].append(signal)
            }
            // 每个 agent 只保留最近 3 条
            for (agentId, sigs) in grouped {
                grouped[agentId] = Array(
                    sigs.sorted { $0.createdAt > $1.createdAt }.prefix(3)
                )
            }
            signalsByAgent = grouped
        } catch {
            errorHandler?.handle(error, context: "加载 Agent 平台")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 计算指标

    func signalCount(for agent: AgentProfile) -> Int {
        signalsByAgent[agent.id]?.count ?? 0
    }

    func avgScore(for agent: AgentProfile) -> String {
        guard let sigs = signalsByAgent[agent.id], !sigs.isEmpty else { return "N/A" }
        let scores = sigs.compactMap { $0.overallScore }
        guard !scores.isEmpty else { return "N/A" }
        return String(format: "%.1f", scores.reduce(0, +) / Double(scores.count))
    }

    func recentSignals(for agent: AgentProfile) -> [AgentSignal] {
        signalsByAgent[agent.id] ?? []
    }
}
