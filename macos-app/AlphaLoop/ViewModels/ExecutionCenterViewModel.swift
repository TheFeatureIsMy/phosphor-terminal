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

    // MARK: - Action Methods

    @MainActor func cancelOrder(id: String) async {
        do { _ = try await api.cancelOrder(id: id); await loadOrdersPositions() } catch { self.error = error.localizedDescription }
    }

    @MainActor func closePosition(id: String) async {
        do { _ = try await api.closePosition(id: id); await loadOrdersPositions() } catch { self.error = error.localizedDescription }
    }

    @MainActor func cancelAllOrders() async {
        do { _ = try await api.cancelAllOrders(); await loadOrdersPositions() } catch { self.error = error.localizedDescription }
    }

    @MainActor func forceCloseAllPositions() async {
        do { _ = try await api.forceCloseAllPositions(); await loadOrdersPositions() } catch { self.error = error.localizedDescription }
    }

    @MainActor func retryReconciliationRun(id: String) async {
        do { _ = try await api.retryReconciliationRun(id: id); await loadReconciliationBus() } catch { self.error = error.localizedDescription }
    }

    @MainActor func retryReconciliationBatch() async {
        do { _ = try await api.retryReconciliationBatch(); await loadReconciliationBus() } catch { self.error = error.localizedDescription }
    }

    @MainActor func emergencyStop() async {
        do { _ = try await APIEmergency(client: api.client).emergencyStop(reason: "manual_emergency_stop") as EmergencyStopResult; await loadCenter() } catch { self.error = error.localizedDescription }
    }

    @MainActor func emergencyResume(strategyRunId: String) async {
        do { _ = try await APIEmergency(client: api.client).emergencyResume(strategyRunId: strategyRunId) as EmergencyStopResult; await loadCenter() } catch { self.error = error.localizedDescription }
    }
}
