// APIDashboard.swift — 仪表盘相关 API

import Foundation

struct APIDashboard {
    let client: NetworkClientProtocol

    func getKPIs() async throws -> DashboardKPIs {
        try await client.get("/api/dashboard/kpis", mock: MockData.mockDashboardKPIs)
    }

    func getEquityCurve() async throws -> [EquityPoint] {
        try await client.get("/api/dashboard/equity-curve", mock: MockData.mockEquityCurve)
    }

    func getSystemStatus() async throws -> SystemStatus {
        try await client.get("/api/system/status", mock: MockData.mockSystemStatus)
    }

    func getRiskEvents() async throws -> [RiskEvent] {
        try await client.get("/api/risk/events", mock: MockData.mockRiskEvents)
    }

    func getCorrelation() async throws -> [CorrelationSnapshot] {
        try await client.get("/api/portfolio/correlation", mock: MockData.mockCorrelation)
    }
}
