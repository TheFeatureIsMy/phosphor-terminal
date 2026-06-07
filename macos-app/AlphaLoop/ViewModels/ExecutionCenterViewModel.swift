// ExecutionCenterViewModel.swift — 执行中心 ViewModel

import SwiftUI

@Observable
@MainActor
final class ExecutionCenterViewModel {
    var centerData: ExecutionCenterBFFResponse?
    var ordersPositions: OrdersPositionsBFFResponse?
    var reconciliationBus: ReconciliationBusBFFResponse?
    var isLoading = false
    var error: String?

    private let api: APIExecutionBFF

    init(client: NetworkClientProtocol) {
        self.api = APIExecutionBFF(client: client)
    }

    func loadCenter() async {
        isLoading = true
        defer { isLoading = false }
        do {
            centerData = try await api.getCenter()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadOrdersPositions() async {
        do {
            ordersPositions = try await api.getOrdersPositions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadReconciliationBus() async {
        do {
            reconciliationBus = try await api.getReconciliationBus()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
