// APIRiskPoliciesAndPools.swift — lookup endpoints for the ⌘4 binding picker
// Plan 2026-06-18 Task 22. Backend router: app/routers/risk_lookup.py

import Foundation

// MARK: - Response types

struct RiskPolicyVersionSummary: Codable, Identifiable, Hashable {
    let id: String
    let riskPolicyId: String
    let policyName: String
    let versionNo: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case riskPolicyId = "risk_policy_id"
        case policyName = "policy_name"
        case versionNo = "version_no"
    }
}

struct CapitalPoolDetail: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let poolType: String
    let currency: String
    let totalBudget: Double
    let maxPositionPctPerTrade: Double
    let maxTotalExposurePct: Double
    let maxDailyLossPct: Double
    let maxDrawdownPct: Double

    enum CodingKeys: String, CodingKey {
        case id, name, currency
        case poolType = "pool_type"
        case totalBudget = "total_budget"
        case maxPositionPctPerTrade = "max_position_pct_per_trade"
        case maxTotalExposurePct = "max_total_exposure_pct"
        case maxDailyLossPct = "max_daily_loss_pct"
        case maxDrawdownPct = "max_drawdown_pct"
    }
}

// MARK: - API client

struct APIRiskLookup {
    let client: any NetworkClientProtocol

    func listRiskPolicyVersions(status: String = "active") async throws -> [RiskPolicyVersionSummary] {
        try await client.get("/api/risk-policy-versions?status=\(status)", mock: {
            [
                RiskPolicyVersionSummary(
                    id: "00000000-0000-0000-0000-000000000001",
                    riskPolicyId: "00000000-0000-0000-0000-0000000000a1",
                    policyName: "Default Conservative",
                    versionNo: 3,
                    status: "active"
                ),
                RiskPolicyVersionSummary(
                    id: "00000000-0000-0000-0000-000000000002",
                    riskPolicyId: "00000000-0000-0000-0000-0000000000a2",
                    policyName: "Aggressive Live",
                    versionNo: 1,
                    status: "active"
                ),
            ]
        })
    }

    func listCapitalPools(poolType: String? = nil) async throws -> [CapitalPoolDetail] {
        var path = "/api/capital-pools"
        if let pt = poolType { path += "?pool_type=\(pt)" }
        return try await client.get(path, mock: {
            [
                CapitalPoolDetail(
                    id: "00000000-0000-0000-0000-0000000000b1",
                    name: "Live Small — USDT",
                    poolType: "live_small",
                    currency: "USDT",
                    totalBudget: 1000.0,
                    maxPositionPctPerTrade: 0.10,
                    maxTotalExposurePct: 0.30,
                    maxDailyLossPct: 0.03,
                    maxDrawdownPct: 0.08
                )
            ]
        })
    }
}
