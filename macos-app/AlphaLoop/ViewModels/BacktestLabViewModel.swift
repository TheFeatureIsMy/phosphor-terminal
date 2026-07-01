// BacktestLabViewModel.swift — 回测实验室聚合 ViewModel (Phase 状态机 + 轮询 + 双 Tab)
//
// Task 7 rewrite: RunTab + RunConfig, real dryrun, compare-set logic, no useMockClient toggle.
// Backward-compatible property names (recentBacktests, recentDryruns, selectedRun, etc.)
// kept for existing Section views. New properties: activeTab, submittedConfig, currentDryrunRun.

import Foundation
import SwiftUI

// MARK: - RunTab + RunConfig

enum RunTab: String, CaseIterable, Identifiable {
    case backtest, dryrun
    var id: String { rawValue }
}

struct RunConfig: Hashable {
    var strategyId: Int = 0
    var strategyUuid: String
    var symbols: [String]
    var timeframe: String
    var initialCapital: Double
    var fee: Double
    var slippageBps: Double
    // backtest-only
    var startDate: String?
    var endDate: String?
    // dryrun-only
    var stakeAmount: Double?
    var maxOpenTrades: Int?
    var initialWallet: Double?
}

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

    // MARK: - Tab & config (new in Task 7)

    var activeTab: RunTab = .backtest
    var submittedConfig: RunConfig?

    // MARK: - Core properties (backward-compat names)

    var selectedStrategy: StrategyV2?
    var selectedRun: BacktestRunV2?
    var recentBacktests: [BacktestRunV2] = []
    var recentDryruns: [StrategyRunV2] = []
    var comparedRuns: [BacktestRunV2] = []
    var comparedRunIds: Set<Int> = []
    var strategyFailureClusters: [FailureClusterSummary] = []
    var readiness: PerStrategyReadiness?
    var errorMessage: String?

    // New dryrun properties
    var currentBacktestRun: BacktestRunV2?
    var currentDryrunRun: DryRunRunV2?
    var dryrunRuns: [DryRunRunV2] = []

    // Available strategies for the picker
    var availableStrategies: [StrategyV2] = []
    var availableVersions: [StrategyVersionV2] = []
    var selectedVersion: StrategyVersionV2?
    var tradableSymbols: [String] = []

    // Network client — set by BacktestLabView via .task { viewModel.networkClient = networkClient }
    var networkClient: NetworkClientProtocol = MockNetworkClient()

    // Polling
    var pollingTask: Task<Void, Never>?
    var pollStartTime: Date?
    private let pollTimeout: TimeInterval = 15 * 60  // 15-minute hard limit

    // MARK: - Init

    init() {}

    // MARK: - Test helper

    func injectPhaseForTest(_ p: Phase) { self.phase = p }

    // MARK: - Initial load (new in Task 7)

    func loadInitial() async {
        await loadAvailableStrategies()
        await loadRunHistory()
    }

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
        await loadVersions()
    }

    func loadAvailableStrategies() async {
        do {
            availableStrategies = try await APIStrategiesV2(client: networkClient).list()
        } catch {
            // silent: picker will show empty
        }
    }

    // MARK: - Strategy version loading

    func loadVersions() async {
        guard let strategy = selectedStrategy else { return }
        do {
            availableVersions = try await APIStrategiesV2(client: networkClient).listVersions(strategyId: strategy.id)
            // Auto-select latest published version; fall back to first
            selectedVersion = availableVersions.first { $0.status == "published" } ?? availableVersions.first
        } catch {
            availableVersions = []
            selectedVersion = nil
        }
    }

    func selectVersion(_ v: StrategyVersionV2) {
        selectedVersion = v
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

            // Populate tradable symbols from workspace data dependencies
            self.tradableSymbols = snap.dataDependencies.symbols

            // Auto-select first backtest
            if comparedRunIds.isEmpty, let first = self.recentBacktests.first {
                comparedRunIds.insert(first.id)
                selectedRun = first
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Run history (new in Task 7)

    func loadRunHistory() async {
        switch activeTab {
        case .backtest:
            do {
                let uuid = selectedStrategy?.id
                recentBacktests = try await networkClient.listBacktestsV2(strategyUuid: uuid, limit: 20)
            } catch {
                // silent: empty list
            }
        case .dryrun:
            do {
                let api = APIDryrunV2(client: networkClient)
                let runs = try await api.listDryruns(strategyId: nil, limit: 20)
                dryrunRuns = runs
            } catch {
                dryrunRuns = []
            }
        }
    }

    func switchTab(_ tab: RunTab) {
        activeTab = tab
        comparedRunIds = []
        comparedRuns = []
        Task { await loadRunHistory() }
    }

    // MARK: - Load tradable symbols

    func loadTradableSymbols(for strategy: StrategyV2) async {
        do {
            let snap = try await networkClient.getWorkspaceSnapshot(strategyId: strategy.id)
            tradableSymbols = snap.dataDependencies.symbols
        } catch {
            tradableSymbols = defaultSymbols
        }
    }

    private var defaultSymbols: [String] {
        ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"]
    }

    // MARK: - Start backtest

    func startBacktest(
        timerange: String,
        symbols: [String],
        capital: Double,
        slippageBps: Double? = nil
    ) async throws {
        guard let strategy = selectedStrategy else { return }

        let config = RunConfig(
            strategyId: 0,
            strategyUuid: strategy.id,
            symbols: symbols,
            timeframe: timerange,
            initialCapital: capital,
            fee: 0.0,
            slippageBps: slippageBps ?? 0,
            startDate: nil,
            endDate: nil
        )
        submittedConfig = config
        phase = .running
        pollStartTime = Date()

        let resp = try await networkClient.startBacktestV2(
            dsl: (selectedVersion?.ruleDsl ?? [:]),
            timerange: timerange,
            symbols: symbols,
            initialCapital: capital,
            slippageBps: slippageBps,
            strategyId: 0,
            strategyVersionId: selectedVersion?.id
        )
        startPolling(commandId: resp.commandId)
    }

    // MARK: - Start dryrun (real implementation, not 501)

    func startDryrun(symbols: [String], stakeAmount: Double, maxOpenTrades: Int, capital: Double) async throws {
        guard let strategy = selectedStrategy else { return }

        let config = RunConfig(
            strategyId: 0,
            strategyUuid: strategy.id,
            symbols: symbols,
            timeframe: "",
            initialCapital: capital,
            fee: 0.0,
            slippageBps: 0,
            stakeAmount: stakeAmount,
            maxOpenTrades: maxOpenTrades,
            initialWallet: capital
        )
        submittedConfig = config
        phase = .running
        errorMessage = nil

        do {
            let api = APIDryrunV2(client: networkClient)
            _ = try await api.startDryrun([
                "dsl": selectedVersion?.ruleDsl ?? [:],
                "strategy_id": Int(selectedStrategy?.id ?? "0") ?? 0,
                "symbols": symbols,
                "stake_amount": stakeAmount,
                "max_open_trades": maxOpenTrades,
                "initial_wallet": capital,
            ])
            // Dryrun is long-lived; brief confirm start, then leave completed.
            phase = .completed
            await loadRunHistory()
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    func stopDryrun(id: Int) async {
        do {
            _ = try await APIDryrunV2(client: networkClient).stopDryrun(String(id))
            await loadRunHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncDryrun(id: Int) async {
        do {
            _ = try await APIDryrunV2(client: networkClient).syncDryrun(id)
            await loadRunHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectDryrunRun(_ run: DryRunRunV2) async {
        currentDryrunRun = run
        if phase != .completed { phase = .completed }
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
                            self.currentBacktestRun = run
                            self.phase = .completed
                        }
                        await self.loadReadinessAndClusters()
                        await self.loadRunHistory()
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
        do {
            let full = try await networkClient.getBacktestV2(id: run.id)
            selectedRun = full
            currentBacktestRun = full
        } catch {
            // Fall back to summary if fetch fails
            selectedRun = run
            currentBacktestRun = run
            errorMessage = error.localizedDescription
        }
        if phase == .running { cancelPolling() }
        if phase != .completed { phase = .completed }
        await loadReadinessAndClusters()
        await loadRunHistory()
    }

    // MARK: - Toggle compare

    func toggleCompare(runId: Int) async {
        if comparedRunIds.contains(runId) {
            comparedRunIds.remove(runId)
            comparedRuns.removeAll { $0.id == runId }
        } else {
            if comparedRunIds.count >= 3 {
                // Max 3; remove oldest to make room
                let oldest = comparedRunIds.first!
                comparedRunIds.remove(oldest)
                comparedRuns.removeAll { $0.id == oldest }
            }
            comparedRunIds.insert(runId)
            do {
                let r = try await networkClient.getBacktestV2(id: runId)
                comparedRuns.append(r)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - New run

    func newRun() {
        phase = .idle
        selectedRun = nil
        currentBacktestRun = nil
        currentDryrunRun = nil
        submittedConfig = nil
        errorMessage = nil
    }

    // MARK: - Failure clusters + readiness

    private func loadReadinessAndClusters() async {
        guard let strategy = selectedStrategy else { return }
        do {
            let snap = try await networkClient.getWorkspaceSnapshot(strategyId: strategy.id)
            readiness = snap.readiness
        } catch {
            readiness = nil
        }
        guard let uuid = UUID(uuidString: strategy.id) else {
            // strategy id isn't a valid UUID — skip silently
            return
        }
        do {
            strategyFailureClusters = try await networkClient.getFailureClusters(strategyUuid: uuid)
        } catch {
            // silent: clusters section shows empty state
        }
    }

    // MARK: - Cleanup

    func onDisappear() {
        cancelPolling()
    }
}
