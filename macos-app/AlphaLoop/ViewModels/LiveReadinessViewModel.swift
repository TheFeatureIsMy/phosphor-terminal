// LiveReadinessViewModel.swift — 实盘准入 ViewModel

import SwiftUI

struct StrategyGate: Identifiable {
    var id: String { key }
    let key: String
    let shortLabel: String
    let passed: Bool
    let remedy: String
}

struct RiskFirewallState {
    var dailyLossUsed: Double = 0
    var dailyLossLimit: Double = 0.03
    var weeklyLossUsed: Double = 0
    var weeklyLossLimit: Double = 0.08
    var consecutiveLosses: Double = 0
    var consecutiveLimit: Double = 5
    var killSwitchActive: Bool = false
}

struct CircuitBreakerState {
    var tradesToday: Int = 0
    var dailyPnl: Double = 0
    var consecutiveLosses: Int = 0
    var shouldStop: Bool = false
    var shouldCooldown: Bool = false
}

struct CapitalConfig {
    var totalBudget: String = "500"
    var stakeAmount: String = "50"
    var maxOpenTrades: String = "3"
    var maxDailyLossPct: String = "3.0"

    var totalBudgetValue: Double { Double(totalBudget) ?? 0 }
    var stakeAmountValue: Double { Double(stakeAmount) ?? 0 }
    var maxOpenTradesInt: Int { Int(maxOpenTrades) ?? 0 }
}

// Keep the computed property directly on the struct but accessible as Double for calculations
extension CapitalConfig {
    var stakeDouble: Double { stakeAmountValue }
}

@Observable
@MainActor
final class LiveReadinessViewModel {
    var data: LiveReadinessResponse?
    var isLoading = false
    var isChecking = false
    var error: String?
    var showLaunchConfirmation = false

    var strategyGates: [StrategyGate] = []
    var riskState = RiskFirewallState()
    var breakerState = CircuitBreakerState()
    var capitalConfig = CapitalConfig()

    private let api: APIOverview

    init(client: NetworkClientProtocol) {
        self.api = APIOverview(client: client)
        self.strategyGates = Self.mockGates()
        self.riskState = Self.mockRiskState()
        self.breakerState = Self.mockBreakerState()
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            data = try await api.getLiveReadiness()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func runCheck() async {
        isChecking = true
        defer { isChecking = false }
        do {
            data = try await api.runReadinessCheck()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func mockGates() -> [StrategyGate] {
        [
            StrategyGate(key: "version_status", shortLabel: L10n.zh("版本状态", en: "Version"), passed: true, remedy: L10n.zh("策略版本需达到 paper_passed 状态", en: "Strategy version must reach paper_passed")),
            StrategyGate(key: "backtest", shortLabel: L10n.zh("回测记录", en: "Backtest"), passed: true, remedy: L10n.zh("至少需要 1 次回测记录", en: "At least 1 backtest required")),
            StrategyGate(key: "dryrun_duration", shortLabel: L10n.zh("模拟时长", en: "Dry-run"), passed: true, remedy: L10n.zh("Dry-run 需运行 ≥ 72 小时", en: "Dry-run must run ≥ 72 hours")),
            StrategyGate(key: "dryrun_health", shortLabel: L10n.zh("模拟健康", en: "Health"), passed: true, remedy: L10n.zh("Dry-run 不能有 failed 状态", en: "Dry-run must not have failed status")),
            StrategyGate(key: "risk_binding", shortLabel: L10n.zh("风控绑定", en: "Risk Bind"), passed: false, remedy: L10n.zh("需要绑定 live_small 的 RiskPolicy + CapitalPool", en: "Must bind live_small RiskPolicy + CapitalPool")),
            StrategyGate(key: "human_confirm", shortLabel: L10n.zh("人工确认", en: "Confirm"), passed: false, remedy: L10n.zh("CapitalPool 必须 requires_human_confirm = true", en: "CapitalPool requires_human_confirm must be true")),
            StrategyGate(key: "no_duplicate", shortLabel: L10n.zh("无重复", en: "No Dup"), passed: true, remedy: L10n.zh("同一策略不能有两个 live_small 运行", en: "Cannot have duplicate live_small runs")),
        ]
    }

    private static func mockRiskState() -> RiskFirewallState {
        RiskFirewallState(dailyLossUsed: 0.008, dailyLossLimit: 0.03, weeklyLossUsed: 0.015, weeklyLossLimit: 0.08, consecutiveLosses: 1, consecutiveLimit: 5, killSwitchActive: false)
    }

    private static func mockBreakerState() -> CircuitBreakerState {
        CircuitBreakerState(tradesToday: 4, dailyPnl: -0.008, consecutiveLosses: 1, shouldStop: false, shouldCooldown: false)
    }
}
