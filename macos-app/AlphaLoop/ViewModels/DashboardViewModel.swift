// DashboardViewModel.swift — Dashboard ViewModel (BFF-backed)
// Consumes the single DashboardBFFResponse from APIOverview.

import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: BFF-mapped state

    var state: String = "healthy"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var account: AccountOverviewResponse?
    var runtime: RuntimeOverviewResponse?
    var risk: RiskOverviewResponse?
    var system: SystemOverviewResponse?
    var recentDecisions: [RecentDecisionResponse] = []
    var alerts: [AlertResponse] = []

    // MARK: Supplementary (not yet in BFF)

    var equityCurve: [EquityPoint] = []

    // MARK: UI state

    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    // MARK: Private

    private let client: NetworkClientProtocol
    private let dashboardAPI: APIDashboard
    private var pollingTask: Task<Void, Never>?

    // MARK: - Init

    init(client: NetworkClientProtocol) {
        self.client = client
        self.dashboardAPI = APIDashboard(client: client)
    }

    // MARK: - Public API

    /// Full initial load: BFF + equity curve in parallel.
    func load() async {
        isLoading = true
        error = nil
        do {
            async let bffTask = dashboardAPI.getDashboardBFF()
            async let curveTask = dashboardAPI.getEquityCurve()

            let bff = try await bffTask
            applyBFF(bff)

            equityCurve = (try? await curveTask) ?? []
        } catch {
            errorHandler?.handle(error, context: "加载仪表盘数据")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Lightweight refresh via BFF only (equity curve unchanged).
    func refresh() async {
        do {
            let bff = try await dashboardAPI.getDashboardBFF()
            applyBFF(bff)
            error = nil
        } catch {
            errorHandler?.handle(error, context: "刷新仪表盘数据")
            self.error = error.localizedDescription
        }
    }

    /// Start 30-second polling loop.
    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
            }
        }
    }

    /// Stop polling.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Global emergency stop, then reload.
    func emergencyStop() async {
        do {
            let emergency = APIEmergency(client: client)
            _ = try await emergency.emergencyStop(reason: "User triggered emergency stop from dashboard")
            await load()
        } catch {
            errorHandler?.handle(error, context: "紧急停止")
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private

    private func applyBFF(_ bff: DashboardBFFResponse) {
        state = bff.state
        reasonCodes = bff.reasonCodes
        availableActions = bff.availableActions
        account = bff.account
        runtime = bff.runtime
        risk = bff.risk
        system = bff.system
        recentDecisions = bff.recentDecisions
        alerts = bff.alerts
    }
}
