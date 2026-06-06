// RiskCenterViewModel.swift — 风控中心 ViewModel

import SwiftUI

@Observable
@MainActor
final class RiskCenterViewModel {
    var overview: RiskOverviewBFFResponse?
    var stopProtection: StopProtectionBFFResponse?
    var circuitBreakers: CircuitBreakersBFFResponse?
    var isLoading = false
    var error: String?

    private let api: APIRiskBFF

    init(client: NetworkClientProtocol) {
        self.api = APIRiskBFF(client: client)
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

    func emergencyStop() async {
        do {
            _ = try await api.emergencyStop()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
