// RiskCenterViewModel.swift — 风控中心 ViewModel

import SwiftUI

@Observable
@MainActor
final class RiskCenterViewModel {
    var overview: RiskOverviewBFFResponse?
    var stopProtection: StopProtectionBFFResponse?
    var circuitBreakers: CircuitBreakersBFFResponse?
    var riskRules: RiskRulesResponse?
    var isLoading = false
    var error: String?

    private let api: APIRiskBFF
    private let executionAPI: APIExecutionBFF

    init(client: NetworkClientProtocol) {
        self.api = APIRiskBFF(client: client)
        self.executionAPI = APIExecutionBFF(client: client)
    }

    func loadOverview() async {
        isLoading = true
        defer { isLoading = false }
        do {
            overview = try await api.getOverview()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadStopProtection() async {
        do {
            stopProtection = try await api.getStopProtection()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadCircuitBreakers() async {
        do {
            circuitBreakers = try await api.getCircuitBreakers()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Risk Rules

    func loadRiskRules() async {
        do {
            riskRules = try await api.getRiskRules()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Block / Unblock New Entries

    func blockNewEntries() async {
        do {
            _ = try await api.blockNewEntries()
            await loadOverview()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unblock() async {
        do {
            _ = try await api.unblock()
            await loadOverview()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Circuit Breaker

    func resolveCircuitBreaker(eventId: String) async {
        do {
            _ = try await api.resolveCircuitBreaker(eventId: eventId)
            await loadCircuitBreakers()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Close Position (delegates to execution API)

    @MainActor func closePosition(id: String) async {
        do {
            _ = try await executionAPI.closePosition(id: id)
            await loadStopProtection()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Emergency

    func emergencyStop() async {
        do {
            _ = try await api.emergencyStop()
            await loadOverview()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Resume requires per-run IDs. The risk overview does not carry stopped-run information,
    /// so this redirects the user to Execution Center where per-run resume is available.
    func emergencyResume() async {
        self.error = "请前往执行中心恢复指定策略运行"
    }
}
