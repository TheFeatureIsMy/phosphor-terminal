// BacktestLabViewModel.swift — 回测实验室聚合 ViewModel (Phase 状态机 + 轮询)
//
// Task 11 rewrite: Phase state machine (idle/configuring/running/completed/failed),
// polling logic (2s interval, 15-min hard timeout), workspace snapshot loading.
// Legacy API surface removed in Task 17.

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

    // MARK: - Core properties

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

    // Available strategies for the picker
    var availableStrategies: [StrategyV2] = []

    // Polling
    var pollingTask: Task<Void, Never>?
    var pollStartTime: Date?
    private let pollTimeout: TimeInterval = 15 * 60  // 15-minute hard limit

    // MARK: - Init

    init() {}

    // MARK: - Test helper

    func injectPhaseForTest(_ p: Phase) { self.phase = p }

    // MARK: - Strategy selection

    func selectStrategy(_ s: StrategyV2) async {
        cancelPolling()
        selectedStrategy = s
        selectedRun = nil
        comparedRuns = []
        comparedRunIds = []
        strategyFailureClusters = []
        readiness = nil
        phase = .configuring
        await loadWorkspaceSnapshot()
    }

    func loadAvailableStrategies() async {
        do {
            availableStrategies = try await APIStrategiesV2(client: networkClient).list()
        } catch {
            // silent: picker will show empty
        }
    }

    // MARK: - Load workspace snapshot

    func loadWorkspaceSnapshot() async {
        guard let sId = selectedStrategy?.id else { return }
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

            // Auto-select first backtest
            if comparedRunIds.isEmpty, let first = self.recentBacktests.first {
                comparedRunIds.insert(first.id)
                selectedRun = first
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
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

    // MARK: - Toggle compare

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

    // MARK: - Cleanup

    func onDisappear() {
        cancelPolling()
    }
}
