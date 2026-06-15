// APIManipulation.swift — Manipulation Detection API (scan, scores, radar, cases, alerts)

import Foundation

// MARK: - Radar Response Types

struct ManipulationCaseSummary: Codable, Identifiable, Hashable {
    var id: String = ""
    var symbol: String = ""
    var manipulationType: String = ""
    var lifecycleStage: String = "suspected"
    var confidence: Double = 0
    var tradingSignalAction: String = ""
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol
        case manipulationType = "manipulation_type"
        case lifecycleStage = "lifecycle_stage"
        case confidence
        case tradingSignalAction = "trading_signal_action"
        case createdAt = "created_at"
    }
}

struct ManipulationRadarOverview: Codable {
    var activeCases: [ManipulationCaseSummary] = []
    var totalActive: Int = 0
    var byStage: [String: Int] = [:]
    var highRiskSymbols: [String] = []
    var recentAlerts: [ManipulationAlertItem] = []

    enum CodingKeys: String, CodingKey {
        case activeCases = "active_cases"
        case totalActive = "total_active"
        case byStage = "by_stage"
        case highRiskSymbols = "high_risk_symbols"
        case recentAlerts = "recent_alerts"
    }
}

struct ManipulationAlertItem: Codable, Identifiable, Hashable {
    var id: String = ""
    var caseId: String = ""
    var alertType: String = ""
    var severity: String = "info"
    var title: String = ""
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case caseId = "case_id"
        case alertType = "alert_type"
        case severity, title
        case createdAt = "created_at"
    }
}

struct ManipulationTradingSignal: Codable, Hashable {
    var action: String = ""
    var direction: String = "none"
    var sizing: String = ""
    var stopLoss: String = ""
    var rationale: String = ""
    var riskLevel: String = "high"

    enum CodingKeys: String, CodingKey {
        case action, direction, sizing
        case stopLoss = "stop_loss"
        case rationale
        case riskLevel = "risk_level"
    }
}

struct ManipulationStageEntry: Codable, Hashable {
    var stage: String = ""
    var enteredAt: String = ""
    var confidence: Double = 0

    enum CodingKeys: String, CodingKey {
        case stage, confidence
        case enteredAt = "entered_at"
    }
}

struct ManipulationCaseDetail: Codable, Identifiable {
    var id: String = ""
    var symbol: String = ""
    var market: String = "crypto"
    var manipulationType: String = ""
    var lifecycleStage: String = "suspected"
    var confidence: Double = 0
    var evidence: [String: Double] = [:]
    var timeline: [ManipulationStageEntry] = []
    var outcome: [String: Double] = [:]
    var tradingSignal: ManipulationTradingSignal = ManipulationTradingSignal()
    var createdAt: String = ""
    var updatedAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol, market, evidence, timeline, outcome, confidence
        case manipulationType = "manipulation_type"
        case lifecycleStage = "lifecycle_stage"
        case tradingSignal = "trading_signal"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ManipulationSignalItem: Codable, Identifiable, Hashable {
    var id: String = ""
    var caseId: String = ""
    var symbol: String = ""
    var action: String = ""
    var direction: String = "none"
    var riskLevel: String = "high"
    var rationale: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol, action, direction, rationale
        case caseId = "case_id"
        case riskLevel = "risk_level"
    }
}

// MARK: - Mock Data

enum MockManipulation {
    static var radarOverview: ManipulationRadarOverview {
        ManipulationRadarOverview(
            activeCases: [
                ManipulationCaseSummary(id: "mock-1", symbol: "SOL/USDT", manipulationType: "M5", lifecycleStage: "markup", confidence: 0.78, tradingSignalAction: "RIDE", createdAt: "2026-06-15T10:00:00Z"),
                ManipulationCaseSummary(id: "mock-2", symbol: "PEPE/USDT", manipulationType: "M3", lifecycleStage: "distribute", confidence: 0.85, tradingSignalAction: "EXIT", createdAt: "2026-06-14T08:00:00Z"),
                ManipulationCaseSummary(id: "mock-3", symbol: "DOGE/USDT", manipulationType: "M8", lifecycleStage: "suspected", confidence: 0.45, tradingSignalAction: "WATCH", createdAt: "2026-06-15T14:00:00Z"),
            ],
            totalActive: 3,
            byStage: ["suspected": 1, "markup": 1, "distribute": 1],
            highRiskSymbols: ["PEPE/USDT"],
            recentAlerts: [
                ManipulationAlertItem(id: "a1", caseId: "mock-2", alertType: "stage_change", severity: "critical", title: "PEPE/USDT: markup → distribute", createdAt: "2026-06-15T12:00:00Z"),
                ManipulationAlertItem(id: "a2", caseId: "mock-1", alertType: "stage_change", severity: "warning", title: "SOL/USDT: accumulate → markup", createdAt: "2026-06-15T10:30:00Z"),
            ]
        )
    }

    static var caseDetail: ManipulationCaseDetail {
        ManipulationCaseDetail(
            id: "mock-1", symbol: "SOL/USDT", market: "crypto",
            manipulationType: "M5", lifecycleStage: "markup", confidence: 0.78,
            evidence: ["pump_dump": 65, "volume_zscore": 55, "price_range_spike": 48],
            timeline: [
                ManipulationStageEntry(stage: "suspected", enteredAt: "2026-06-14T08:00:00Z", confidence: 0.45),
                ManipulationStageEntry(stage: "accumulate", enteredAt: "2026-06-14T16:00:00Z", confidence: 0.62),
                ManipulationStageEntry(stage: "markup", enteredAt: "2026-06-15T10:00:00Z", confidence: 0.78),
            ],
            tradingSignal: ManipulationTradingSignal(action: "RIDE", direction: "long", sizing: "medium", stopLoss: "trailing", rationale: "Markup confirmed — ride with trailing stop", riskLevel: "medium"),
            createdAt: "2026-06-14T08:00:00Z", updatedAt: "2026-06-15T10:00:00Z"
        )
    }

    static var alerts: [ManipulationAlertItem] {
        [
            ManipulationAlertItem(id: "a1", caseId: "mock-2", alertType: "stage_change", severity: "critical", title: "PEPE/USDT: markup → distribute", createdAt: "2026-06-15T12:00:00Z"),
            ManipulationAlertItem(id: "a2", caseId: "mock-1", alertType: "stage_change", severity: "warning", title: "SOL/USDT: accumulate → markup", createdAt: "2026-06-15T10:30:00Z"),
            ManipulationAlertItem(id: "a3", caseId: "mock-3", alertType: "new_case", severity: "info", title: "New case: DOGE/USDT (M8 Liquidity Hunt)", createdAt: "2026-06-15T14:00:00Z"),
        ]
    }
}

// MARK: - API

struct APIManipulation {
    let client: NetworkClientProtocol

    // MARK: - Legacy (scan / scores)

    func scanSymbol(_ body: [String: Any]) async throws -> ManipulationScoreV2 {
        try await client.post("/api/v2/manipulation/scan", body: AnyEncodable(body)) {
            ManipulationScoreV2(
                id: UUID().uuidString,
                symbol: "BTC/USDT",
                manipulationScore: 0.35,
                stopHuntScore: 0.28,
                holderConcentrationScore: 0.22,
                liquidityTrapScore: 0.42,
                pumpDumpScore: 0.15,
                fundingSqueezeScore: 0.20,
                riskLevel: "medium",
                suggestion: "Exercise caution — moderate manipulation signals detected. Elevated liquidity trap score on 15m candles. Consider reducing position size.",
                updatedAt: "2026-06-05T12:00:00Z"
            )
        }
    }

    func listScores(limit: Int = 20) async throws -> [ManipulationScoreV2] {
        try await client.get("/api/v2/manipulation/scores?limit=\(limit)") {
            [
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "BTC/USDT",
                    manipulationScore: 0.18,
                    stopHuntScore: 0.10,
                    holderConcentrationScore: 0.15,
                    liquidityTrapScore: 0.12,
                    pumpDumpScore: 0.08,
                    fundingSqueezeScore: 0.05,
                    riskLevel: "low",
                    suggestion: "Market appears clean. Normal trading conditions.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "ETH/USDT",
                    manipulationScore: 0.62,
                    stopHuntScore: 0.55,
                    holderConcentrationScore: 0.48,
                    liquidityTrapScore: 0.70,
                    pumpDumpScore: 0.45,
                    fundingSqueezeScore: 0.72,
                    riskLevel: "high",
                    suggestion: "High manipulation risk. Stop-hunt activity detected near key liquidation levels. Abnormal funding squeeze pattern. Avoid new entries until conditions normalize.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "SOL/USDT",
                    manipulationScore: 0.85,
                    stopHuntScore: 0.82,
                    holderConcentrationScore: 0.90,
                    liquidityTrapScore: 0.78,
                    pumpDumpScore: 0.88,
                    fundingSqueezeScore: 0.75,
                    riskLevel: "critical",
                    suggestion: "Critical manipulation alert. Extreme holder concentration with coordinated pump-dump pattern. Volume 8x rolling 7-day average with no catalyst. Do NOT trade this pair.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
                ManipulationScoreV2(
                    id: UUID().uuidString,
                    symbol: "DOGE/USDT",
                    manipulationScore: 0.05,
                    stopHuntScore: 0.03,
                    holderConcentrationScore: 0.08,
                    liquidityTrapScore: 0.04,
                    pumpDumpScore: 0.02,
                    fundingSqueezeScore: 0.03,
                    riskLevel: "low",
                    suggestion: "Market appears clean. Normal trading conditions.",
                    updatedAt: "2026-06-05T11:00:00Z"
                ),
            ]
        }
    }

    func getScore(_ symbol: String) async throws -> ManipulationScoreV2 {
        try await client.get("/api/v2/manipulation/scores/\(symbol)") {
            ManipulationScoreV2(
                id: UUID().uuidString,
                symbol: symbol,
                manipulationScore: 0.35,
                stopHuntScore: 0.28,
                holderConcentrationScore: 0.22,
                liquidityTrapScore: 0.42,
                pumpDumpScore: 0.15,
                fundingSqueezeScore: 0.20,
                riskLevel: "medium",
                suggestion: "Exercise caution — moderate manipulation signals detected. Elevated liquidity trap score on 15m candles.",
                updatedAt: "2026-06-05T12:00:00Z"
            )
        }
    }

    // MARK: - Radar (lifecycle-based)

    func getRadarOverview() async throws -> ManipulationRadarOverview {
        try await client.get("/api/v2/manipulation/radar") {
            MockManipulation.radarOverview
        }
    }

    func getCaseDetail(_ caseId: String) async throws -> ManipulationCaseDetail {
        try await client.get("/api/v2/manipulation/cases/\(caseId)") {
            MockManipulation.caseDetail
        }
    }

    func getAlerts(limit: Int = 20) async throws -> [ManipulationAlertItem] {
        try await client.get("/api/v2/manipulation/alerts?limit=\(limit)") {
            MockManipulation.alerts
        }
    }

    func getSignals(userProfile: String = "conservative") async throws -> [ManipulationSignalItem] {
        try await client.get("/api/v2/manipulation/signals?user_profile=\(userProfile)") {
            [ManipulationSignalItem]()
        }
    }
}
