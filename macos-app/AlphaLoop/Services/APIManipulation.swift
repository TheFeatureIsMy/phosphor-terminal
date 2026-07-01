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
    var tradingSignal: DualTradingSignal = DualTradingSignal()
    var createdAt: String = ""
    var updatedAt: String = ""

    // v2 fields (optional for backward compat with mock/old responses)
    var riskLevel: String = ""
    var evidenceLayers: [String: EvidenceLayerPayload]? = nil
    var completeness: Double = 0
    var maxConfidence: Double = 0
    var affectedSymbols: [String]? = nil
    var sources: [ManipulationSource]? = nil

    enum CodingKeys: String, CodingKey {
        case id, symbol, market, evidence, timeline, outcome, confidence
        case manipulationType = "manipulation_type"
        case lifecycleStage = "lifecycle_stage"
        case tradingSignal = "trading_signal"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case riskLevel = "risk_level"
        case evidenceLayers = "evidence_layers"
        case completeness
        case maxConfidence = "max_confidence"
        case affectedSymbols = "affected_symbols"
        case sources
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

struct EvidenceLayerPayload: Codable {
    var available: Bool = false
    var score: Double = 0
    var quality: Double = 0
    var features: [String: FeaturePayload] = [:]
}

struct FeaturePayload: Codable {
    var value: Double = 0
    var percentile: Double? = nil
    var display: String? = nil
}

struct DualTradingSignal: Codable {
    var conservative: ManipulationTradingSignal = ManipulationTradingSignal()
    var aggressive: ManipulationTradingSignal = ManipulationTradingSignal()
}

struct ManipulationSource: Codable {
    var type: String = ""
    var ruleId: String = ""
    var version: String = ""

    enum CodingKeys: String, CodingKey {
        case type
        case ruleId = "rule_id"
        case version
    }
}

struct StrategyImpactItem: Codable, Identifiable {
    var id: String { strategyId }
    var strategyId: String = ""
    var strategyName: String = ""
    var wouldBlock: Bool = false
    var reasonCodes: [String] = []
    var currentValue: Double = 0
    var threshold: Double = 0

    enum CodingKeys: String, CodingKey {
        case strategyId = "strategy_id"
        case strategyName = "strategy_name"
        case wouldBlock = "would_block"
        case reasonCodes = "reason_codes"
        case currentValue = "current_value"
        case threshold
    }
}

struct StrategyImpactResponse: Codable {
    var caseId: String = ""
    var affectedStrategies: [StrategyImpactItem] = []

    enum CodingKeys: String, CodingKey {
        case caseId = "case_id"
        case affectedStrategies = "affected_strategies"
    }
}

struct SimilarCaseItem: Codable, Identifiable {
    var id: String = ""
    var symbol: String = ""
    var manipulationType: String = ""
    var similarity: Double = 0
    var outcome: [String: Double] = [:]
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol, similarity, outcome
        case manipulationType = "manipulation_type"
        case createdAt = "created_at"
    }
}

struct SimilarCasesResponse: Codable {
    var caseId: String = ""
    var similar: [SimilarCaseItem] = []

    enum CodingKeys: String, CodingKey {
        case caseId = "case_id"
        case similar
    }
}

enum ManipulationEvent: Codable {
    case stageChange(caseId: String, oldStage: String, newStage: String, ts: String)
    case newCase(caseId: String, symbol: String, mType: String, ts: String)
    case snapshot(activeCases: [ManipulationCaseSummary], ts: String)
    case heartbeat(ts: String)
    case unknown

    enum CodingKeys: String, CodingKey { case type, case_id, symbol, manipulation_type, old_stage, new_stage, ts, active_cases }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        switch type {
        case "stage_change":
            self = .stageChange(
                caseId: try c.decodeIfPresent(String.self, forKey: .case_id) ?? "",
                oldStage: try c.decodeIfPresent(String.self, forKey: .old_stage) ?? "",
                newStage: try c.decodeIfPresent(String.self, forKey: .new_stage) ?? "",
                ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        case "new_case":
            self = .newCase(
                caseId: try c.decodeIfPresent(String.self, forKey: .case_id) ?? "",
                symbol: try c.decodeIfPresent(String.self, forKey: .symbol) ?? "",
                mType: try c.decodeIfPresent(String.self, forKey: .manipulation_type) ?? "",
                ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        case "snapshot":
            let cases = try c.decodeIfPresent([ManipulationCaseSummary].self, forKey: .active_cases) ?? []
            self = .snapshot(activeCases: cases, ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        case "heartbeat":
            self = .heartbeat(ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {} // not used
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
            tradingSignal: DualTradingSignal(
                conservative: ManipulationTradingSignal(action: "RIDE", direction: "long", sizing: "medium", stopLoss: "trailing", rationale: "Markup confirmed — ride with trailing stop", riskLevel: "medium"),
                aggressive: ManipulationTradingSignal(action: "EXIT", direction: "short", sizing: "small", stopLoss: "tight", rationale: "Markup nearing exhaustion — prepare to exit", riskLevel: "high")
            ),
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

    static func strategyImpact(caseId: String) -> StrategyImpactResponse {
        StrategyImpactResponse(
            caseId: caseId,
            affectedStrategies: [
                StrategyImpactItem(strategyId: "strat-1", strategyName: "BTC Momentum v3", wouldBlock: true, reasonCodes: ["filter_matched"], currentValue: 0.78, threshold: 0.6),
                StrategyImpactItem(strategyId: "strat-2", strategyName: "SOL Breakout v2", wouldBlock: false, reasonCodes: ["filter_disabled"], currentValue: 0.78, threshold: 0.6),
            ])
    }

    static func similarCases(caseId: String) -> SimilarCasesResponse {
        SimilarCasesResponse(
            caseId: caseId,
            similar: [
                SimilarCaseItem(id: "hist-1", symbol: "DOGE/USDT", manipulationType: "M3", similarity: 0.91, outcome: ["realized_drawdown": -0.18, "recovery_hours": 36], createdAt: "2026-05-10T08:00:00Z"),
                SimilarCaseItem(id: "hist-2", symbol: "WIF/USDT", manipulationType: "M3", similarity: 0.84, outcome: ["realized_drawdown": -0.22, "recovery_hours": 48], createdAt: "2026-04-22T12:00:00Z"),
            ])
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

    func getStrategyImpact(_ caseId: String) async throws -> StrategyImpactResponse {
        try await client.get("/api/v2/manipulation/cases/\(caseId)/strategy-impact") {
            MockManipulation.strategyImpact(caseId: caseId)
        }
    }

    func getSimilar(_ caseId: String, limit: Int = 5) async throws -> SimilarCasesResponse {
        try await client.get("/api/v2/manipulation/cases/\(caseId)/similar?limit=\(limit)") {
            MockManipulation.similarCases(caseId: caseId)
        }
    }
}
