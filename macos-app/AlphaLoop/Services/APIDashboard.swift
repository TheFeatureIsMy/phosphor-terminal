// APIDashboard.swift — Dashboard BFF API (delegates to APIOverview)

import Foundation

struct APIDashboard {
    let client: NetworkClientProtocol

    func getDashboardBFF() async throws -> DashboardBFFResponse {
        let api = APIOverview(client: client)
        return try await api.getDashboard()
    }

    // Legacy: equity curve for sparkline (kept until BFF includes it)
    func getEquityCurve() async throws -> [EquityPoint] {
        try await client.get("/api/dashboard/equity-curve", mock: MockData.mockEquityCurve)
    }

    // Used by RiskView / StrategyRiskTab (not part of Dashboard BFF)
    func getRiskEvents() async throws -> [RiskEvent] {
        try await client.get("/api/risk/events", mock: MockData.mockRiskEvents)
    }

    func getCorrelation() async throws -> [CorrelationSnapshot] {
        try await client.get("/api/portfolio/correlation", mock: MockData.mockCorrelation)
    }
}
