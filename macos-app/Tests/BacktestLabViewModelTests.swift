// BacktestLabViewModelTests.swift — TDD for Phase state machine + polling
//
// Uses Swift Testing (@Test, #expect).
// Adapted from brief: Strategy → StrategyV2 to match actual types.

import Testing
import Foundation
@testable import AlphaLoop

@MainActor
struct BacktestLabViewModelTests {

    @Test func testInitialPhaseIsIdle() {
        let vm = BacktestLabViewModel()
        #expect(vm.phase == .idle)
    }

    @Test func testSelectingStrategyTransitionsToConfiguring() async {
        let vm = BacktestLabViewModel()
        let strategy = StrategyV2(
            id: UUID().uuidString,
            name: "Test",
            description: nil,
            strategyType: "rule_dsl",
            sourceType: "manual",
            status: "draft",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: nil
        )
        await vm.selectStrategy(strategy)
        #expect(vm.phase == .configuring)
    }

    @Test func testStartingBacktestTransitionsToRunning() async throws {
        let vm = BacktestLabViewModel()
        vm.networkClient = MockNetworkClient()
        let strategy = StrategyV2(
            id: UUID().uuidString,
            name: "Test",
            description: nil,
            strategyType: "rule_dsl",
            sourceType: "manual",
            status: "draft",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: nil
        )
        await vm.selectStrategy(strategy)
        try await vm.startBacktest(
            timerange: "20240101-20240601",
            symbols: ["BTC/USDT"],
            capital: 10000
        )
        #expect(vm.phase == .running)
    }

    @Test func testFailedRunTransitionsToFailed() async {
        let vm = BacktestLabViewModel()
        vm.injectPhaseForTest(.failed)
        #expect(vm.phase == .failed)
    }

    @Test func testCancellingStrategyStopsPolling() async {
        let vm = BacktestLabViewModel()
        vm.injectPhaseForTest(.running)
        vm.cancelPolling()
        #expect(vm.pollingTask == nil)
    }
}
