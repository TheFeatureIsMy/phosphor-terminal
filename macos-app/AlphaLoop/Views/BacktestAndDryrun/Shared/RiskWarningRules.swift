// RiskWarningRules.swift — Pure functions for backtest risk warnings
// Produces sorted [RiskWarning] from BacktestMetrics, used by BacktestLabView

import Foundation

enum RiskWarningLevel: String, Codable {
    case red, yellow
}

struct RiskWarning: Identifiable, Hashable {
    let id: String
    let level: RiskWarningLevel
}

/// Evaluates a set of BacktestMetrics and returns risk warnings.
/// Red warnings (critical) are sorted first, then yellow (cautionary).
/// At most 5 warnings are returned.
/// Note: This is a pure function intentionally free of L10n calls (which require
/// MainActor). Views should resolve display messages via `riskWarningMessage(id:)`.
func riskWarnings(for m: BacktestMetrics) -> [RiskWarning] {
    var ws: [RiskWarning] = []

    if m.maxDrawdown <= -0.25 {
        ws.append(RiskWarning(id: "max_drawdown", level: .red))
    }
    if m.profitFactor < 1.0 {
        ws.append(RiskWarning(id: "profit_factor", level: .red))
    }
    if m.totalTrades < 30 {
        ws.append(RiskWarning(id: "low_trades", level: .yellow))
    }
    if m.winRate < 0.35 {
        ws.append(RiskWarning(id: "low_winrate", level: .yellow))
    }
    if m.sharpeRatio < 0 {
        ws.append(RiskWarning(id: "negative_sharpe", level: .yellow))
    }

    // Sort: reds first, yellows second; same level preserves insertion order
    let reds = ws.filter { $0.level == .red }
    let yellows = ws.filter { $0.level == .yellow }
    return Array((reds + yellows).prefix(5))
}

/// Resolves a risk warning's display message by its id.
/// Must be called on the main actor because it accesses L10n strings.
@MainActor
func riskWarningMessage(id: String) -> String {
    switch id {
    case "max_drawdown": return L10n.BacktestLab.warnMaxDrawdown
    case "profit_factor": return L10n.BacktestLab.warnProfitFactor
    case "low_trades": return L10n.BacktestLab.warnLowTrades
    case "low_winrate": return L10n.BacktestLab.warnLowWinrate
    case "negative_sharpe": return L10n.BacktestLab.warnNegativeSharpe
    default: return ""
    }
}
