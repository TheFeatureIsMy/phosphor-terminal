// DashboardViewModel.swift — 仪表盘视图模型
// 负责加载 KPI、权益曲线、持仓、订单、风险事件，支持定时轮询

import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    var kpis: DashboardKPIs?
    var equityCurve: [EquityPoint] = []
    var positions: [Position] = []
    var orders: [Order] = []
    var riskEvents: [RiskEvent] = []
    var systemStatus: SystemStatus?
    var correlationSnapshots: [CorrelationSnapshot] = []
    var isLoading = true
    var error: String?
    var errorHandler: ErrorHandler?

    private let dashboardAPI: APIDashboard
    private let ordersAPI: APIOrders
    private var pollingTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.dashboardAPI = APIDashboard(client: client)
        self.ordersAPI = APIOrders(client: client)
    }

    /// 加载所有数据
    func loadAll() async {
        isLoading = true
        error = nil
        do {
            async let kpisTask = dashboardAPI.getKPIs()
            async let curveTask = dashboardAPI.getEquityCurve()
            async let positionsTask = ordersAPI.listPositions()
            async let ordersTask = ordersAPI.listOrders(limit: 20)
            async let eventsTask = dashboardAPI.getRiskEvents()

            kpis = try await kpisTask
            equityCurve = try await curveTask
            positions = try await positionsTask
            orders = try await ordersTask
            riskEvents = try await eventsTask
            systemStatus = try? await dashboardAPI.getSystemStatus()
            correlationSnapshots = (try? await dashboardAPI.getCorrelation()) ?? []
        } catch {
            errorHandler?.handle(error, context: "加载仪表盘数据")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 启动轮询（KPI 30s，持仓 15s）
    func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                await self.refreshData()
            }
        }
    }

    /// 停止轮询
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// 静默刷新数据（不显示 loading）
    private func refreshData() async {
        do {
            async let kpisTask = dashboardAPI.getKPIs()
            async let positionsTask = ordersAPI.listPositions()
            kpis = try await kpisTask
            positions = try await positionsTask
        } catch {
            // 静默失败，不覆盖已有数据
        }
    }
}
