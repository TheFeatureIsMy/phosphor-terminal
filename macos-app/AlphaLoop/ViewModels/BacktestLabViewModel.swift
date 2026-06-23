// BacktestLabViewModel.swift — 回测实验室聚合 ViewModel (Phase 状态机 + 轮询)
//
// Task 11 rewrite: Phase state machine (idle/configuring/running/completed/failed),
// polling logic (2s interval, 15-min hard timeout), workspace snapshot loading.
//
// Preserves old API surface (strategies, runs, dryruns, comparedRunIds, etc.)
// for BacktestLabView.swift compatibility. Task 17 will remove the legacy surface.

import Foundation
import SwiftUI

// MARK: - NetworkClientProtocol extension for workspace snapshot

extension NetworkClientProtocol {
    /// GET /api/v2/strategies/{id}/workspace — full BFF aggregation.
    func getWorkspaceSnapshot(strategyId: String) async throws -> WorkspaceSnapshot {
        try await APIStrategyWorkspace(client: self).getSnapshot(strategyId: strategyId)
    }
}

@Observable
@MainActor
final class BacktestLabViewModel {

    // MARK: - Phase state machine

    enum Phase: Equatable {
        case idle, configuring, running, completed, failed
    }

    var phase: Phase = .idle

    // MARK: - New properties (Task 11 rewrite)

    var selectedStrategy: StrategyV2?
    var selectedRun: BacktestRunV2?
    var recentBacktests: [BacktestRunV2] = []
    var recentDryruns: [StrategyRunV2] = []
    var comparedRuns: [BacktestRunV2] = []
    var comparedRunIds: Set<Int> = []
    var strategyFailureClusters: [FailureClusterSummary] = []
    var readiness: PerStrategyReadiness?
    var errorMessage: String?

    // Network client with mock toggle
    var networkClient: NetworkClientProtocol = MockNetworkClient()
    var useMockClient: Bool = true {
        didSet { networkClient = useMockClient ? MockNetworkClient() : LiveNetworkClient() }
    }

    // Polling
    var pollingTask: Task<Void, Never>?
    var pollStartTime: Date?
    private let pollTimeout: TimeInterval = 15 * 60  // 15-minute hard limit

    // MARK: - Legacy API surface (preserved for BacktestLabView.swift, to be removed in Task 17)

    var strategies: [StrategyV2] = []
    var selectedStrategyId: String?
    var showNewRunSheet = false
    var isLoading = false
    var loadError: String? {
        get { errorMessage }
        set { errorMessage = newValue }
    }

    /// Legacy alias — maps to recentBacktests
    var runs: [BacktestRunV2] { recentBacktests }

    /// Legacy alias — maps to recentDryruns
    var dryruns: [StrategyRunV2] { recentDryruns }

    var inspectedRunId: Int?

    var inspectedRun: BacktestRunV2? {
        guard let id = inspectedRunId else { return nil }
        return recentBacktests.first { $0.id == id }
    }

    /// Champion: completed run with highest Sharpe, maxDD > -25
    var championRun: BacktestRunV2? {
        let pool = recentBacktests.filter { $0.status == "completed" && $0.maxDrawdown > -25 }
        return pool.max { $0.sharpeRatio < $1.sharpeRatio }
    }

    // MARK: - Init

    init() {}

    /// Legacy init for BacktestLabView.swift (injects network client)
    convenience init(client: NetworkClientProtocol) {
        self.init()
        self.networkClient = client
        self.useMockClient = client is MockNetworkClient
    }

    // MARK: - Test helper

    func injectPhaseForTest(_ p: Phase) { self.phase = p }

    // MARK: - Strategy selection (new — takes StrategyV2)

    func selectStrategy(_ s: StrategyV2) async {
        cancelPolling()
        selectedStrategy = s
        selectedStrategyId = s.id
        selectedRun = nil
        comparedRuns = []
        comparedRunIds = []
        strategyFailureClusters = []
        readiness = nil
        phase = .configuring
        await loadWorkspaceSnapshot()
    }

    // MARK: - Strategy selection (legacy — takes id string)

    func selectStrategy(_ id: String) async {
        if let s = strategies.first(where: { $0.id == id }) {
            await selectStrategy(s)
        } else {
            selectedStrategyId = id
            phase = .configuring
            await loadWorkspaceSnapshot()
        }
    }

    // MARK: - Load workspace snapshot

    func loadWorkspaceSnapshot() async {
        guard let sId = selectedStrategyId else { return }
        isLoading = true
        do {
            let snap = try await networkClient.getWorkspaceSnapshot(strategyId: sId)

            // Map BacktestRunSummary → BacktestRunV2
            self.recentBacktests = snap.recentBacktests.map { summary in
                BacktestRunV2(
                    id: summary.id,
                    strategyId: 0,
                    strategyVersionId: nil,
                    commandId: nil,
                    dslHash: nil,
                    status: summary.status,
                    startDate: summary.startedAt ?? "",
                    endDate: summary.completedAt ?? "",
                    initialCapital: 0,
                    symbols: [],
                    config: [:],
                    result: [:],
                    sharpeRatio: summary.sharpeRatio ?? 0,
                    maxDrawdown: -(summary.maxDrawdown ?? 0),
                    winRate: (summary.winRate ?? 0),
                    totalReturn: (summary.totalReturn ?? 0),
                    profitFactor: 0,
                    totalTrades: 0,
                    errorMessage: nil,
                    createdAt: summary.startedAt,
                    completedAt: summary.completedAt,
                    equityCurve: [],
                    trades: []
                )
            }

            // Map StrategyRunSummary → StrategyRunV2
            self.recentDryruns = snap.recentDryruns.map { srs in
                StrategyRunV2(
                    id: srs.id,
                    strategyVersionId: "",
                    mode: srs.mode,
                    status: srs.status,
                    startedAt: srs.startedAt,
                    stoppedAt: srs.stoppedAt,
                    createdAt: srs.createdAt ?? "",
                    configSnapshot: nil,
                    resultSummary: nil
                )
            }

            self.readiness = snap.readiness

            // Auto-select first backtest for inspector
            if comparedRunIds.isEmpty, let first = self.recentBacktests.first {
                comparedRunIds.insert(first.id)
                inspectedRunId = first.id
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Start backtest

    func startBacktest(
        timerange: String,
        symbols: [String],
        capital: Double,
        slippageBps: Double? = nil
    ) async throws {
        guard selectedStrategy != nil else { return }
        let resp = try await networkClient.startBacktestV2(
            dsl: [:],
            timerange: timerange,
            symbols: symbols,
            initialCapital: capital,
            slippageBps: slippageBps,
            strategyId: 0,
            strategyVersionId: nil
        )
        phase = .running
        pollStartTime = Date()
        startPolling(commandId: resp.commandId)
    }

    // MARK: - Start dryrun

    func startDryrun(symbols: [String], stakeAmount: Double, maxOpenTrades: Int, capital: Double) async throws {
        guard let s = selectedStrategy else { return }
        let api = APIDryrunV2(client: networkClient)
        var body: [String: Any] = [
            "dsl": [:] as [String: Any],
            "symbols": symbols,
            "stake_amount": stakeAmount,
            "max_open_trades": maxOpenTrades,
            "initial_wallet": capital,
            "exchange": "binance",
        ]
        if let uuid = UUID(uuidString: s.id) {
            body["strategy_id"] = uuid.uuidString
        } else {
            body["strategy_id"] = s.id
        }
        let _ = try await api.startDryrun(body)
        // Dryruns are long-running (live paper trading); "command queued" is the success condition.
        phase = .completed
    }

    // MARK: - Polling

    private func startPolling(commandId: String) {
        cancelPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let start = self.pollStartTime, Date().timeIntervalSince(start) > self.pollTimeout {
                    await MainActor.run { self.phase = .failed; self.errorMessage = L10n.BacktestLab.timeoutError }
                    return
                }
                do {
                    let status = try await self.networkClient.backtestStatusV2(commandId: commandId)
                    if status.commandStatus == "completed", let run = status.backtestRun {
                        await MainActor.run {
                            self.selectedRun = run
                            self.phase = .completed
                        }
                        await self.loadFailureClusters()
                        return
                    }
                    if ["failed", "error", "cancelled"].contains(status.commandStatus) {
                        await MainActor.run {
                            self.phase = .failed
                            self.errorMessage = status.errorMessage ?? L10n.BacktestLab.runFailed
                        }
                        return
                    }
                } catch {
                    // Network transient error — continue polling
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Select run

    func selectRun(_ run: BacktestRunV2) async {
        selectedRun = run
        if phase != .running { phase = .completed }
        await loadFailureClusters()
    }

    // MARK: - Toggle compare (async — new)

    func toggleCompare(runId: Int) async {
        if comparedRunIds.contains(runId) {
            comparedRunIds.remove(runId)
            comparedRuns.removeAll { $0.id == runId }
        } else {
            guard comparedRunIds.count < 3 else { return }
            comparedRunIds.insert(runId)
            do {
                let r = try await networkClient.getBacktestV2(id: runId)
                comparedRuns.append(r)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Toggle compare (legacy — non-async, for view compatibility)

    func toggleCompare(_ runId: Int) {
        if comparedRunIds.contains(runId) {
            comparedRunIds.remove(runId)
            if inspectedRunId == runId {
                inspectedRunId = comparedRunIds.first
            }
        } else {
            if comparedRunIds.count >= 3 {
                if let first = comparedRunIds.first { comparedRunIds.remove(first) }
            }
            comparedRunIds.insert(runId)
            inspectedRunId = runId
        }
    }

    func inspect(_ runId: Int) {
        inspectedRunId = runId
        comparedRunIds.insert(runId)
    }

    // MARK: - Failure clusters

    private func loadFailureClusters() async {
        guard let s = selectedStrategy else { return }
        guard let uuid = UUID(uuidString: s.id) else {
            // strategy id isn't a UUID — skip failure clusters silently
            return
        }
        do {
            self.strategyFailureClusters = try await networkClient.getFailureClusters(strategyUuid: uuid)
        } catch {
            // silent: clusters section shows empty state
        }
    }

    // MARK: - Legacy bootstrap / loadRuns / submitNewRun

    func bootstrap() async {
        isLoading = true
        loadError = nil
        do {
            strategies = try await APIStrategiesV2(client: networkClient).list()
            if selectedStrategyId == nil {
                selectedStrategyId = strategies.first?.id
            }
            if let id = selectedStrategyId, let s = strategies.first(where: { $0.id == id }) {
                await selectStrategy(s)
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func loadRuns() async {
        await loadWorkspaceSnapshot()
    }

    func submitNewRun(
        versionId: String?,
        start: String,
        end: String,
        capital: Double,
        symbols: [String]
    ) async -> Bool {
        do {
            try await startBacktest(
                timerange: "\(start)-\(end)",
                symbols: symbols,
                capital: capital
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func onDisappear() {
        cancelPolling()
    }
}
