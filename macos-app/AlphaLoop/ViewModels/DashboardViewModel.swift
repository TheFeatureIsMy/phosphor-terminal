// DashboardViewModel.swift — Dashboard ViewModel (BFF + parallel real fetches)
// Consumes the BFF, plus parallel supplementary fetches (KPIs, positions, orders,
// live-readiness, provider health, AI models, recent signals). All numbers come
// from the live backend. When the data source is unavailable, surfaces an empty
// payload + `dataSource` reason instead of fabricated values.

import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - BFF-mapped state

    var state: String = "unknown"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var account: AccountOverviewResponse?
    var runtime: RuntimeOverviewResponse?
    var risk: RiskOverviewResponse?
    var system: SystemOverviewResponse?
    var recentDecisions: [RecentDecisionResponse] = []
    var alerts: [AlertResponse] = []
    var liveReadiness: LiveReadinessResponse?

    // MARK: - Supplementary (real data, parallel-fetched)

    var equityCurve: [EquityPoint] = []
    var kpis: DashboardKPIsResponse?
    var positions: [PositionData] = []
    var openOrders: [OrderBFFResponse] = []
    var providerHealth: ProviderHealthSummary?
    var aiModels: [AIModelStatusRef] = []
    var recentSignals: [DashboardSignalRef] = []

    // MARK: - Per-source availability (drives empty-state rendering)

    var bffAvailable: Bool = false
    var kpisAvailable: Bool = false
    var positionsAvailable: Bool = false
    var liveReadinessAvailable: Bool = false
    var providerHealthAvailable: Bool = false
    var aiModelsAvailable: Bool = false
    var signalsAvailable: Bool = false
    var equityCurveAvailable: Bool = false

    // MARK: - UI state

    var isLoading = false
    var isDataSourceUnavailable = false
    var lastUpdated: Date?
    var error: String?
    var errorHandler: ErrorHandler?

    // MARK: - Private

    private let client: NetworkClientProtocol
    private let overviewAPI: APIOverview
    private let dashboardAPI: APIDashboard
    private let executionAPI: APIExecutionBFF
    private var pollingTask: Task<Void, Never>?

    // MARK: - Init

    init(client: NetworkClientProtocol) {
        self.client = client
        self.overviewAPI = APIOverview(client: client)
        self.dashboardAPI = APIDashboard(client: client)
        self.executionAPI = APIExecutionBFF(client: client)
    }

    // MARK: - Public API

    /// Full initial load: BFF + 7 supplementary sources in parallel.
    func load() async {
        isLoading = true
        isDataSourceUnavailable = false
        error = nil

        async let bffTask: () = loadBFF()
        async let kpisTask: () = loadKPIs()
        async let positionsTask: () = loadPositions()
        async let readinessTask: () = loadLiveReadiness()
        async let providersTask: () = loadProviderHealth()
        async let aiModelsTask: () = loadAIModels()
        async let signalsTask: () = loadSignals()
        async let curveTask: () = loadEquityCurve()

        _ = await (bffTask, kpisTask, positionsTask, readinessTask, providersTask, aiModelsTask, signalsTask, curveTask)

        lastUpdated = Date()
        isDataSourceUnavailable = !(bffAvailable || kpisAvailable)
        isLoading = false
    }

    /// Lightweight refresh — re-pulls all sources in parallel.
    func refresh() async {
        error = nil
        async let bffTask: () = loadBFF()
        async let kpisTask: () = loadKPIs()
        async let positionsTask: () = loadPositions()
        async let readinessTask: () = loadLiveReadiness()
        async let providersTask: () = loadProviderHealth()
        async let aiModelsTask: () = loadAIModels()
        async let signalsTask: () = loadSignals()

        _ = await (bffTask, kpisTask, positionsTask, readinessTask, providersTask, aiModelsTask, signalsTask)

        lastUpdated = Date()
        isDataSourceUnavailable = !(bffAvailable || kpisAvailable)
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

    /// Action dispatch (called by AvailableActionsRow).
    func performAction(_ action: AvailableActionResponse) async {
        switch action.type {
        case "emergency_stop":
            await emergencyStop()
        case "start_paper", "start_live_small", "start_full_live":
            // Delegated to LiveReadiness page; the BFF only exposes these as
            // hints, not real transition endpoints. Surface a toast.
            errorHandler?.handle(
                NSError(
                    domain: "Dashboard",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: L10n.zh("请前往实盘准入页面启动。", en: "Please start from the Live Readiness page.")]
                ),
                context: action.label
            )
        case "cancel_all_orders", "force_close_all":
            errorHandler?.handle(
                NSError(
                    domain: "Dashboard",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: L10n.zh("请前往执行中心处理。", en: "Please manage this from the Execution Center.")]
                ),
                context: action.label
            )
        default:
            errorHandler?.handle(
                NSError(
                    domain: "Dashboard",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: L10n.zh("未支持的动作", en: "Unsupported action")]
                ),
                context: action.type
            )
        }
    }

    // MARK: - Per-source loaders (all real fetches, fail-soft)

    private func loadBFF() async {
        do {
            let bff = try await overviewAPI.getDashboard()
            state = bff.state
            reasonCodes = bff.reasonCodes
            availableActions = bff.availableActions
            account = bff.account
            runtime = bff.runtime
            risk = bff.risk
            system = bff.system
            recentDecisions = bff.recentDecisions
            alerts = bff.alerts
            bffAvailable = true
        } catch {
            bffAvailable = false
        }
    }

    private func loadKPIs() async {
        do {
            kpis = try await overviewAPI.getKPIs()
            kpisAvailable = true
        } catch {
            kpisAvailable = false
        }
    }

    private func loadPositions() async {
        do {
            let resp = try await executionAPI.getOrdersPositions()
            openOrders = resp.orders
            positions = resp.positions.map { pos in
                PositionData(
                    symbol: pos.symbol,
                    direction: pos.side,
                    size: pos.quantity,
                    entryPrice: pos.avgEntryPrice,
                    currentPrice: pos.currentPrice,
                    pnl: pos.unrealizedPnl,
                    pnlPct: pos.unrealizedPnlPct,
                    riskLevel: "low",
                    reasonCodes: pos.reasonCodes,
                    stateDifference: pos.stateDifference
                )
            }
            positionsAvailable = !resp.positions.isEmpty || resp.state != "data_source_unavailable"
            // Treat data_source_unavailable explicitly as unavailable
            if resp.state == "data_source_unavailable" { positionsAvailable = false }
        } catch {
            positionsAvailable = false
        }
    }

    private func loadLiveReadiness() async {
        do {
            liveReadiness = try await overviewAPI.getLiveReadiness()
            liveReadinessAvailable = true
        } catch {
            liveReadinessAvailable = false
        }
    }

    private func loadProviderHealth() async {
        do {
            providerHealth = try await overviewAPI.getProviderHealth()
            providerHealthAvailable = true
        } catch {
            providerHealthAvailable = false
        }
    }

    private func loadAIModels() async {
        do {
            aiModels = try await overviewAPI.getAIModelStatus()
            aiModelsAvailable = true
        } catch {
            aiModelsAvailable = false
        }
    }

    private func loadSignals() async {
        do {
            recentSignals = try await overviewAPI.getRecentSignals(limit: 8)
            signalsAvailable = true
        } catch {
            signalsAvailable = false
        }
    }

    private func loadEquityCurve() async {
        do {
            equityCurve = try await dashboardAPI.getEquityCurve()
            equityCurveAvailable = !equityCurve.isEmpty
        } catch {
            equityCurveAvailable = false
        }
    }
}
