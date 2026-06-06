// ExecutionRecordsViewModel.swift — 执行记录视图模型
// 加载策略运行列表，按模式/状态过滤，加载运行详情（订单 + 账本）

import SwiftUI

@Observable
@MainActor
final class ExecutionRecordsViewModel {
    var runs: [StrategyRunV2] = []
    var isLoading = false
    var error: String?
    var filterMode: String? = nil
    var filterStatus: String? = nil
    var selectedRun: StrategyRunV2?
    var runOrders: [Order] = []
    var runLedger: [AnyCodable] = []
    var isLoadingDetail = false
    var errorHandler: ErrorHandler?

    private let api: APIStrategyRuns

    init(client: NetworkClientProtocol) {
        self.api = APIStrategyRuns(client: client)
    }

    /// 加载运行列表
    func load() async {
        isLoading = true
        error = nil
        do {
            runs = try await api.listRuns(mode: filterMode, status: filterStatus, limit: 50)
        } catch {
            errorHandler?.handle(error, context: "加载执行记录")
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 加载单个运行的订单和账本详情
    func loadRunDetails(_ runId: String) async {
        isLoadingDetail = true
        do {
            async let ordersTask = api.getRunOrders(runId)
            async let ledgerTask = api.getRunLedger(runId)
            runOrders = try await ordersTask
            runLedger = try await ledgerTask
        } catch {
            errorHandler?.handle(error, context: "加载运行详情")
        }
        isLoadingDetail = false
    }

    /// 按模式和状态过滤后的运行列表
    var filteredRuns: [StrategyRunV2] {
        runs.filter { run in
            (filterMode == nil || run.mode == filterMode) &&
            (filterStatus == nil || run.status == filterStatus)
        }
    }
}
