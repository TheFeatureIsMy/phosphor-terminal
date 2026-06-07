// ViewModelTests.swift — Comprehensive ViewModel tests for PulseDesk
// Tests that all ViewModels load data correctly from MockNetworkClient

import Testing
import Foundation
@testable import AlphaLoop

@Suite("ViewModel Tests")
struct ViewModelTests {

    // MARK: - DashboardViewModel

    @MainActor @Test func dashboardViewModelLoadAll() async {
        let client = MockNetworkClient()
        let vm = DashboardViewModel(client: client)

        await vm.loadAll()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.equityCurve.isEmpty)
    }

    @MainActor @Test func dashboardViewModelApproveConfirmation() async {
        let client = MockNetworkClient()
        let vm = DashboardViewModel(client: client)

        await vm.loadAll()

        let countBefore = vm.pendingConfirmations.count
        if let first = vm.pendingConfirmations.first {
            vm.approveConfirmation(first.id)
            #expect(vm.pendingConfirmations.count == countBefore - 1)
        }
    }

    @MainActor @Test func dashboardViewModelRejectConfirmation() async {
        let client = MockNetworkClient()
        let vm = DashboardViewModel(client: client)

        await vm.loadAll()

        let countBefore = vm.pendingConfirmations.count
        if let first = vm.pendingConfirmations.first {
            vm.rejectConfirmation(first.id)
            #expect(vm.pendingConfirmations.count == countBefore - 1)
        }
    }

    // MARK: - LiveReadinessViewModel

    @MainActor @Test func liveReadinessViewModelLoadData() async {
        let client = MockNetworkClient()
        let vm = LiveReadinessViewModel(client: client)

        await vm.loadData()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.data != nil)
        #expect(vm.data!.score > 0)
        #expect(!vm.data!.state.isEmpty)
    }

    @MainActor @Test func liveReadinessViewModelRunCheck() async {
        let client = MockNetworkClient()
        let vm = LiveReadinessViewModel(client: client)

        await vm.runCheck()

        #expect(vm.isChecking == false)
        #expect(vm.error == nil)
        #expect(vm.data != nil)
    }

    // MARK: - StrategiesViewModel

    @MainActor @Test func strategiesViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = StrategiesViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.strategies.isEmpty)
    }

    @MainActor @Test func strategiesViewModelCreate() async {
        let client = MockNetworkClient()
        let vm = StrategiesViewModel(client: client)

        await vm.load()
        let countBefore = vm.strategies.count

        await vm.create(name: "Test Strategy")

        #expect(vm.error == nil)
        #expect(vm.strategies.count == countBefore + 1)
    }

    // MARK: - ExecutionCenterViewModel

    @MainActor @Test func executionCenterViewModelLoadCenter() async {
        let client = MockNetworkClient()
        let vm = ExecutionCenterViewModel(client: client)

        await vm.loadCenter()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.centerData != nil)
        #expect(!vm.centerData!.state.isEmpty)
        #expect(vm.centerData!.totalRunning > 0)
    }

    @MainActor @Test func executionCenterViewModelLoadOrdersPositions() async {
        let client = MockNetworkClient()
        let vm = ExecutionCenterViewModel(client: client)

        await vm.loadOrdersPositions()

        #expect(vm.error == nil)
        #expect(vm.ordersPositions != nil)
        #expect(!vm.ordersPositions!.orders.isEmpty)
        #expect(!vm.ordersPositions!.positions.isEmpty)
    }

    @MainActor @Test func executionCenterViewModelLoadReconciliationBus() async {
        let client = MockNetworkClient()
        let vm = ExecutionCenterViewModel(client: client)

        await vm.loadReconciliationBus()

        #expect(vm.error == nil)
        #expect(vm.reconciliationBus != nil)
        #expect(!vm.reconciliationBus!.recentCommands.isEmpty)
    }

    // MARK: - RiskCenterViewModel

    @MainActor @Test func riskCenterViewModelLoadOverview() async {
        let client = MockNetworkClient()
        let vm = RiskCenterViewModel(client: client)

        await vm.loadOverview()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.overview != nil)
        #expect(!vm.overview!.state.isEmpty)
        #expect(!vm.overview!.guards.isEmpty)
    }

    @MainActor @Test func riskCenterViewModelLoadStopProtection() async {
        let client = MockNetworkClient()
        let vm = RiskCenterViewModel(client: client)

        await vm.loadStopProtection()

        #expect(vm.error == nil)
        #expect(vm.stopProtection != nil)
        #expect(!vm.stopProtection!.positions.isEmpty)
    }

    @MainActor @Test func riskCenterViewModelLoadCircuitBreakers() async {
        let client = MockNetworkClient()
        let vm = RiskCenterViewModel(client: client)

        await vm.loadCircuitBreakers()

        #expect(vm.error == nil)
        #expect(vm.circuitBreakers != nil)
        #expect(vm.circuitBreakers!.totalCount > 0)
    }

    @MainActor @Test func riskCenterViewModelEmergencyStop() async {
        let client = MockNetworkClient()
        let vm = RiskCenterViewModel(client: client)

        await vm.emergencyStop()

        #expect(vm.error == nil)
    }

    // MARK: - StructureMatrixViewModel

    @MainActor @Test func structureMatrixViewModelLoadMatrix() async {
        let client = MockNetworkClient()
        let vm = StructureMatrixViewModel(client: client)

        await vm.loadMatrix()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.matrixData != nil)
        #expect(!vm.matrixData!.rows.isEmpty)
        #expect(vm.matrixData!.symbol == "BTC/USDT")
    }

    @MainActor @Test func structureMatrixViewModelRefresh() async {
        let client = MockNetworkClient()
        let vm = StructureMatrixViewModel(client: client)

        await vm.refresh()

        #expect(vm.matrixData != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - MarketStructureViewModel

    @MainActor @Test func marketStructureViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = MarketStructureViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.data != nil)
        #expect(!vm.zones.isEmpty)
        #expect(!vm.pools.isEmpty)
        #expect(!vm.events.isEmpty)
        #expect(vm.score > 0)
        #expect(!vm.regime.isEmpty)
    }

    @MainActor @Test func marketStructureViewModelRefresh() async {
        let client = MockNetworkClient()
        let vm = MarketStructureViewModel(client: client)

        await vm.refresh()

        #expect(vm.data != nil)
        #expect(vm.error == nil)
    }

    // MARK: - ManipulationViewModel

    @MainActor @Test func manipulationViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = ManipulationViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.scores.isEmpty)
        #expect(!vm.sortedScores.isEmpty)
    }

    @MainActor @Test func manipulationViewModelScan() async {
        let client = MockNetworkClient()
        let vm = ManipulationViewModel(client: client)

        vm.scanSymbol = "BTC/USDT"
        await vm.scan()

        #expect(!vm.scores.isEmpty)
    }

    // MARK: - SignalCenterViewModel

    @MainActor @Test func signalCenterViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = SignalCenterViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.signals.isEmpty)
        #expect(!vm.filteredSignals.isEmpty)
    }

    @MainActor @Test func signalCenterViewModelTransition() async {
        let client = MockNetworkClient()
        let vm = SignalCenterViewModel(client: client)

        await vm.load()

        guard let signal = vm.signals.first else {
            Issue.record("No signals loaded")
            return
        }
        await vm.transition(signal.id, to: "active")
        // Should not crash
    }

    @MainActor @Test func signalCenterViewModelArchive() async {
        let client = MockNetworkClient()
        let vm = SignalCenterViewModel(client: client)

        await vm.load()

        guard let signal = vm.signals.first else {
            Issue.record("No signals loaded")
            return
        }
        await vm.archive(signal.id)

        let found = vm.signals.first { $0.id == signal.id }
        #expect(found?.status == "archived")
    }

    // MARK: - AgentPlatformViewModel

    @MainActor @Test func agentPlatformViewModelLoadAll() async {
        let client = MockNetworkClient()
        let vm = AgentPlatformViewModel(client: client)

        await vm.loadAll()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.agents.isEmpty)
    }

    @MainActor @Test func agentPlatformViewModelSignalCount() async {
        let client = MockNetworkClient()
        let vm = AgentPlatformViewModel(client: client)

        await vm.loadAll()

        guard let agent = vm.agents.first else {
            Issue.record("No agents loaded")
            return
        }
        #expect(vm.signalCount(for: agent) >= 0)
    }

    // MARK: - GrowthViewModel

    @MainActor @Test func growthViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = GrowthViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.reports.isEmpty)
        #expect(!vm.candidates.isEmpty)
    }

    @MainActor @Test func growthViewModelRunDailyReview() async {
        let client = MockNetworkClient()
        let vm = GrowthViewModel(client: client)

        await vm.runDailyReview()

        #expect(!vm.reports.isEmpty)
    }

    @MainActor @Test func growthViewModelConfirmCandidate() async {
        let client = MockNetworkClient()
        let vm = GrowthViewModel(client: client)

        await vm.load()

        guard let candidate = vm.candidates.first else {
            Issue.record("No candidates loaded")
            return
        }
        await vm.confirmCandidate(candidate.id)
        // Should not crash
    }

    // MARK: - FailureClusteringViewModel

    @MainActor @Test func failureClusteringViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = FailureClusteringViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.data != nil)
        #expect(!vm.clusters.isEmpty)
        #expect(vm.totalLossTrades > 0)
        #expect(vm.totalLossAmount < 0)
        #expect(!vm.labels.isEmpty)
    }

    @MainActor @Test func failureClusteringViewModelRegimeMatrix() async {
        let client = MockNetworkClient()
        let vm = FailureClusteringViewModel(client: client)

        await vm.load()

        #expect(!vm.regimeMatrix.isEmpty)
        #expect(!vm.uniqueRegimes.isEmpty)
        #expect(!vm.uniqueFailureTypes.isEmpty)
        #expect(vm.maxClusterLoss > 0)
    }

    // MARK: - StrategyOptimizationViewModel

    @MainActor @Test func strategyOptimizationViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = StrategyOptimizationViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(!vm.suggestions.isEmpty)
        #expect(!vm.pendingCandidates.isEmpty)
    }

    @MainActor @Test func strategyOptimizationViewModelConfirmCandidate() async {
        let client = MockNetworkClient()
        let vm = StrategyOptimizationViewModel(client: client)

        await vm.load()

        guard let candidate = vm.pendingCandidates.first else {
            Issue.record("No pending candidates loaded")
            return
        }
        await vm.confirmCandidate(candidate.id)
        #expect(vm.error == nil)
    }

    // MARK: - DataSourcesViewModel

    @MainActor @Test func dataSourcesViewModelLoad() async {
        let client = MockNetworkClient()
        let vm = DataSourcesViewModel(client: client)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
        #expect(vm.data != nil)
        #expect(!vm.sources.isEmpty)
        #expect(vm.totalActive > 0)
        #expect(!vm.categories.isEmpty)
    }

    @MainActor @Test func dataSourcesViewModelTestConnection() async {
        let client = MockNetworkClient()
        let vm = DataSourcesViewModel(client: client)

        await vm.load()
        await vm.testConnection("ds-001")

        #expect(vm.error == nil)
        #expect(vm.testingSourceId == nil)
    }

    @MainActor @Test func dataSourcesViewModelToggleSource() async {
        let client = MockNetworkClient()
        let vm = DataSourcesViewModel(client: client)

        await vm.load()

        guard let source = vm.sources.first else {
            Issue.record("No sources loaded")
            return
        }
        await vm.toggleSource(source)
        #expect(vm.error == nil)
    }

    // MARK: - GlobalStatusViewModel

    @MainActor @Test func globalStatusViewModelLoadStatus() async {
        let client = MockNetworkClient()
        let vm = GlobalStatusViewModel(client: client)

        await vm.loadStatus()

        #expect(vm.error == nil)
        #expect(vm.status != nil)
        #expect(!vm.status!.systemState.isEmpty)
    }
}
