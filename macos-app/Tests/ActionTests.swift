// ActionTests.swift — Tests for action handlers in ViewModels
// Verifies that emergency stop, confirm, refresh, toggle, and other actions work

import Testing
import Foundation
@testable import AlphaLoop

@Suite("Action Handler Tests")
struct ActionTests {

    // MARK: - Emergency Stop

    @MainActor @Test func emergencyStop() async {
        let client = MockNetworkClient()
        let vm = RiskCenterViewModel(client: client)

        await vm.emergencyStop()

        #expect(vm.error == nil)
    }

    // MARK: - Data Source Toggle

    @MainActor @Test func dataSourceToggle() async {
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

    // MARK: - Data Source Test Connection

    @MainActor @Test func dataSourceTestConnection() async {
        let client = MockNetworkClient()
        let vm = DataSourcesViewModel(client: client)

        await vm.load()
        await vm.testConnection("ds-001")

        #expect(vm.error == nil)
        #expect(vm.testingSourceId == nil)
    }

    // MARK: - Confirm Candidate (Strategy Optimization)

    @MainActor @Test func confirmCandidate() async {
        let client = MockNetworkClient()
        let vm = StrategyOptimizationViewModel(client: client)

        await vm.load()

        guard let candidate = vm.pendingCandidates.first else {
            Issue.record("No pending candidates available")
            return
        }
        await vm.confirmCandidate(candidate.id)
        #expect(vm.error == nil)
    }

    // MARK: - Live Readiness Check

    @MainActor @Test func liveReadinessCheck() async {
        let client = MockNetworkClient()
        let vm = LiveReadinessViewModel(client: client)

        await vm.runCheck()

        #expect(vm.data != nil)
        #expect(vm.isChecking == false)
        #expect(vm.error == nil)
    }

    // MARK: - Structure Matrix Refresh

    @MainActor @Test func structureMatrixRefresh() async {
        let client = MockNetworkClient()
        let vm = StructureMatrixViewModel(client: client)

        await vm.refresh()

        #expect(vm.matrixData != nil)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    // MARK: - Market Structure Refresh

    @MainActor @Test func marketStructureRefresh() async {
        let client = MockNetworkClient()
        let vm = MarketStructureViewModel(client: client)

        await vm.refresh()

        #expect(vm.data != nil)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    // MARK: - Signal Transition

    @MainActor @Test func signalTransition() async {
        let client = MockNetworkClient()
        let vm = SignalCenterViewModel(client: client)

        await vm.load()

        guard let signal = vm.signals.first else {
            Issue.record("No signals loaded")
            return
        }
        await vm.transition(signal.id, to: "active")
        // Should complete without crash
    }

    // MARK: - Signal Archive

    @MainActor @Test func signalArchive() async {
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

    // MARK: - Growth Daily Review

    @MainActor @Test func growthRunDailyReview() async {
        let client = MockNetworkClient()
        let vm = GrowthViewModel(client: client)

        await vm.runDailyReview()

        #expect(!vm.reports.isEmpty)
    }

    // MARK: - Growth Confirm Candidate

    @MainActor @Test func growthConfirmCandidate() async {
        let client = MockNetworkClient()
        let vm = GrowthViewModel(client: client)

        await vm.load()

        guard let candidate = vm.candidates.first else {
            Issue.record("No candidates loaded")
            return
        }
        await vm.confirmCandidate(candidate.id)
    }

    // MARK: - Manipulation Scan

    @MainActor @Test func manipulationScan() async {
        let client = MockNetworkClient()
        let vm = ManipulationViewModel(client: client)

        vm.scanSymbol = "BTC/USDT"
        await vm.scan()

        #expect(!vm.scores.isEmpty)
    }

    @MainActor @Test func manipulationScanEmptySymbol() async {
        let client = MockNetworkClient()
        let vm = ManipulationViewModel(client: client)

        vm.scanSymbol = ""
        await vm.scan()

        // Empty symbol should be a no-op
        #expect(vm.scores.isEmpty)
    }

    // MARK: - Strategy Create

    @MainActor @Test func strategyCreate() async {
        let client = MockNetworkClient()
        let vm = StrategiesViewModel(client: client)

        await vm.load()
        let countBefore = vm.strategies.count

        await vm.create(name: "New Test Strategy")

        #expect(vm.error == nil)
        #expect(vm.strategies.count == countBefore + 1)
        #expect(vm.strategies[0].name == "New Test Strategy")
    }

    // MARK: - Dashboard Approve/Reject

    @MainActor @Test func dashboardApproveConfirmation() async {
        let client = MockNetworkClient()
        let vm = DashboardViewModel(client: client)

        await vm.loadAll()

        let countBefore = vm.pendingConfirmations.count
        if countBefore > 0 {
            let id = vm.pendingConfirmations[0].id
            vm.approveConfirmation(id)
            #expect(vm.pendingConfirmations.count == countBefore - 1)
            #expect(vm.pendingConfirmations.first { $0.id == id } == nil)
        }
    }

    @MainActor @Test func dashboardRejectConfirmation() async {
        let client = MockNetworkClient()
        let vm = DashboardViewModel(client: client)

        await vm.loadAll()

        let countBefore = vm.pendingConfirmations.count
        if countBefore > 0 {
            let id = vm.pendingConfirmations[0].id
            vm.rejectConfirmation(id)
            #expect(vm.pendingConfirmations.count == countBefore - 1)
            #expect(vm.pendingConfirmations.first { $0.id == id } == nil)
        }
    }

    // MARK: - Global Status Polling

    @MainActor @Test func globalStatusPollingStartStop() async {
        let client = MockNetworkClient()
        let vm = GlobalStatusViewModel(client: client)

        vm.startPolling()
        try? await Task.sleep(for: .milliseconds(100))
        vm.stopPolling()

        #expect(vm.error == nil)
    }
}
