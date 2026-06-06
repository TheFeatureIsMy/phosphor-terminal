// DashboardViewModel.swift — AI 总控台视图模型
// 从真实 API 加载所有数据，不使用 mock

import SwiftUI

// MARK: - Supporting Types

struct AIMarketJudgment: Hashable {
    let direction: String
    let confidence: Double
    let riskLevel: String
    let sourceAgent: String
    let reasoning: String
}

struct PositionWithAI: Identifiable, Hashable {
    let id: String
    let symbol: String
    let direction: String
    let pnl: Double
    let pnlPercent: Double
    let aiRecommendation: String
    let riskLevel: String
}

struct PendingConfirmation: Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let description: String
    let createdAt: String
}

struct AgentSignalGroup: Identifiable, Hashable {
    var id: String { agentName }
    let agentName: String
    let signalCount: Int
    let longCount: Int
    let shortCount: Int
}

struct StrategyStatusSummary: Hashable {
    let draft: Int
    let active: Int
    let dryRunning: Int
    let paused: Int
}

struct RiskInterceptionSummary: Hashable {
    let rejected: Int
    let reduced: Int
    let paperOnly: Int
    let allowed: Int
}

// MARK: - ViewModel

@Observable
@MainActor
final class DashboardViewModel {
    var aiMarketJudgment: AIMarketJudgment?
    var positions: [PositionWithAI] = []
    var pendingConfirmations: [PendingConfirmation] = []
    var agentSignalDistribution: [AgentSignalGroup] = []
    var strategyStatusSummary: StrategyStatusSummary?
    var equityCurve: [EquityPoint] = []
    var riskInterceptions: RiskInterceptionSummary?

    var aiProviderStatus: String = "normal"
    var gpuStatus: String = "idle"
    var todayAICost: Double = 0
    var pendingAIJobs: Int = 0
    var systemStatus: SystemStatus?

    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let dashboardAPI: APIDashboard
    private let signalsAPI: APISignalsV2
    private let strategiesAPI: APIStrategiesV2
    private let ordersAPI: APIOrders
    private let sentimentAPI: APISentiment
    private let inferenceAPI: APIInference
    private var pollingTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.dashboardAPI = APIDashboard(client: client)
        self.signalsAPI = APISignalsV2(client: client)
        self.strategiesAPI = APIStrategiesV2(client: client)
        self.ordersAPI = APIOrders(client: client)
        self.sentimentAPI = APISentiment(client: client)
        self.inferenceAPI = APIInference(client: client)
    }

    func loadAll() async {
        isLoading = true
        error = nil
        do {
            async let curveTask = dashboardAPI.getEquityCurve()
            async let signalsTask: [SignalV2] = { (try? await self.signalsAPI.listSignals(limit: 50)) ?? [] }()
            async let positionsTask: [Position] = { (try? await self.ordersAPI.listPositions()) ?? [] }()
            async let strategiesTask: [StrategyV2] = { (try? await self.strategiesAPI.list()) ?? [] }()
            async let riskEventsTask: [RiskEvent] = { (try? await self.dashboardAPI.getRiskEvents()) ?? [] }()
            async let systemTask: SystemStatus? = try? await self.dashboardAPI.getSystemStatus()
            async let sentimentTask: SentimentSummaryResponse? = try? await self.sentimentAPI.getSummary()
            async let jobsTask: [InferenceJob] = { (try? await self.inferenceAPI.listJobs(limit: 50)) ?? [] }()
            async let runtimeTask: RuntimeStateInfo? = try? await self.inferenceAPI.getRuntimeState()

            equityCurve = try await curveTask

            let signals = await signalsTask
            agentSignalDistribution = buildAgentDistribution(from: signals)

            let sentiment = await sentimentTask
            aiMarketJudgment = buildMarketJudgment(from: signals, sentiment: sentiment)

            let rawPositions = await positionsTask
            positions = buildPositionsWithAI(from: rawPositions, signals: signals)

            let strategies = await strategiesTask
            strategyStatusSummary = buildStrategySummary(from: strategies)

            let riskEvents = await riskEventsTask
            riskInterceptions = buildRiskInterceptions(from: riskEvents)

            systemStatus = await systemTask
            pendingConfirmations = buildPendingConfirmations(from: signals, strategies: strategies)

            // 推理队列 → status bar
            let jobs = await jobsTask
            pendingAIJobs = jobs.filter { $0.status == "pending" || $0.status == "queued" }.count
            todayAICost = jobs.compactMap(\.actualCostUsd).reduce(0, +)

            if let runtime = await runtimeTask {
                gpuStatus = runtime.state == "running" ? "active" : (runtime.state == "error" ? "unavailable" : "idle")
            }
        } catch {
            errorHandler?.handle(error, context: "加载 AI 总控台数据")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                await self.refreshData()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func approveConfirmation(_ id: String) {
        pendingConfirmations.removeAll { $0.id == id }
    }

    func rejectConfirmation(_ id: String) {
        pendingConfirmations.removeAll { $0.id == id }
    }

    // MARK: - Private

    private func refreshData() async {
        let signals = (try? await signalsAPI.listSignals(limit: 50)) ?? []
        agentSignalDistribution = buildAgentDistribution(from: signals)

        let rawPositions = (try? await ordersAPI.listPositions()) ?? []
        positions = buildPositionsWithAI(from: rawPositions, signals: signals)

        let jobs = (try? await inferenceAPI.listJobs(limit: 50)) ?? []
        pendingAIJobs = jobs.filter { $0.status == "pending" || $0.status == "queued" }.count
        todayAICost = jobs.compactMap(\.actualCostUsd).reduce(0, +)
    }

    private func buildAgentDistribution(from signals: [SignalV2]) -> [AgentSignalGroup] {
        var groups: [String: (total: Int, long: Int, short: Int)] = [:]
        for signal in signals {
            var entry = groups[signal.sourceType, default: (0, 0, 0)]
            entry.total += 1
            if signal.direction == "long" { entry.long += 1 } else { entry.short += 1 }
            groups[signal.sourceType] = entry
        }
        return groups.map { AgentSignalGroup(agentName: $0.key, signalCount: $0.value.total, longCount: $0.value.long, shortCount: $0.value.short) }
            .sorted { $0.signalCount > $1.signalCount }
    }

    private func buildMarketJudgment(from signals: [SignalV2], sentiment: SentimentSummaryResponse?) -> AIMarketJudgment? {
        let recent = Array(signals.prefix(10))
        guard !recent.isEmpty else { return nil }

        let longCount = recent.filter { $0.direction == "long" }.count
        let shortCount = recent.filter { $0.direction == "short" }.count

        let direction: String
        if longCount > shortCount * 2 { direction = "看多" }
        else if shortCount > longCount * 2 { direction = "看空" }
        else { direction = "震荡" }

        let avgConfidence = recent.reduce(0.0) { $0 + $1.confidence } / Double(recent.count)
        let topSignal = recent.max(by: { $0.confidence < $1.confidence })

        var reasoning = topSignal?.reasoning ?? ""
        if reasoning.isEmpty, let sentiment {
            reasoning = "市场恐惧贪婪指数 \(sentiment.fearGreedIndex) (\(sentiment.fearGreedLabel))，综合 \(recent.count) 个信号判断"
        }
        if reasoning.isEmpty {
            reasoning = "基于最近 \(recent.count) 个信号综合判断"
        }

        let riskLevel: String
        if avgConfidence >= 0.75 { riskLevel = "low" }
        else if avgConfidence >= 0.5 { riskLevel = "medium" }
        else { riskLevel = "high" }

        return AIMarketJudgment(
            direction: direction,
            confidence: avgConfidence,
            riskLevel: riskLevel,
            sourceAgent: topSignal?.sourceType ?? "mixed",
            reasoning: reasoning
        )
    }

    private func buildPositionsWithAI(from positions: [Position], signals: [SignalV2]) -> [PositionWithAI] {
        positions.filter { $0.status == .open }.map { pos in
            let relatedSignal = signals.first { $0.symbol == pos.symbol }
            let pnlPct = pos.avgPrice > 0 ? (pos.unrealizedPnl / (pos.avgPrice * pos.quantity)) * 100 : 0

            let recommendation: String
            if pos.unrealizedPnl > 0 && pnlPct > 5 { recommendation = "take-profit" }
            else if pos.unrealizedPnl < 0 && pnlPct < -3 { recommendation = "reduce" }
            else if relatedSignal?.direction == "short" && pos.side == .long { recommendation = "close" }
            else { recommendation = "hold" }

            let risk: String
            if abs(pnlPct) > 5 { risk = "high" }
            else if abs(pnlPct) > 2 { risk = "medium" }
            else { risk = "low" }

            return PositionWithAI(
                id: "pos-\(pos.id)",
                symbol: pos.symbol,
                direction: pos.side == .long ? "long" : "short",
                pnl: pos.unrealizedPnl,
                pnlPercent: pnlPct,
                aiRecommendation: recommendation,
                riskLevel: risk
            )
        }
    }

    private func buildStrategySummary(from strategies: [StrategyV2]) -> StrategyStatusSummary {
        var d = 0, a = 0, dr = 0, p = 0
        for s in strategies {
            switch s.status {
            case "draft", "validated", "backtested": d += 1
            case "active", "live_pending", "live_small": a += 1
            case "dry_running", "paper_passed": dr += 1
            case "paused": p += 1
            default: break
            }
        }
        return StrategyStatusSummary(draft: d, active: a, dryRunning: dr, paused: p)
    }

    private func buildRiskInterceptions(from events: [RiskEvent]) -> RiskInterceptionSummary {
        var rejected = 0, reduced = 0, paperOnly = 0, allowed = 0
        for e in events {
            switch e.actionTaken {
            case "rejected", "blocked": rejected += 1
            case "reduced", "downgraded": reduced += 1
            case "paper_only", "dry_run_only": paperOnly += 1
            default: allowed += 1
            }
        }
        return RiskInterceptionSummary(rejected: rejected, reduced: reduced, paperOnly: paperOnly, allowed: allowed)
    }

    private func buildPendingConfirmations(from signals: [SignalV2], strategies: [StrategyV2]) -> [PendingConfirmation] {
        var items: [PendingConfirmation] = []

        for signal in signals.prefix(20) where signal.status == "pending" {
            items.append(PendingConfirmation(
                id: "sig-\(signal.id)",
                type: "dry_run",
                title: "信号待处理: \(signal.symbol) \(signal.direction)",
                description: signal.reasoning ?? "置信度 \(Int(signal.confidence * 100))%",
                createdAt: signal.createdAt
            ))
        }

        for s in strategies where s.status == "backtested" || s.status == "paper_passed" {
            items.append(PendingConfirmation(
                id: "strat-\(s.id)",
                type: "strategy_deploy",
                title: "策略待部署: \(s.name)",
                description: "状态: \(s.status)，等待确认后进入下一阶段",
                createdAt: s.updatedAt ?? ""
            ))
        }

        return Array(items.prefix(5))
    }
}
