// RiskWarningRules.swift — Pure functions for backtest risk warnings
// Produces sorted [RiskWarning] from BacktestMetrics, used by BacktestLabView

import Foundation

enum RiskWarningLevel: String, Codable {
    case red, yellow
}

struct RiskWarning: Identifiable, Hashable {
    let id: String
    let level: RiskWarningLevel
    let message: String
}

/// Evaluates a set of BacktestMetrics and returns risk warnings.
/// Red warnings (critical) are sorted first, then yellow (cautionary).
/// At most 5 warnings are returned.
func riskWarnings(for m: BacktestMetrics) -> [RiskWarning] {
    var ws: [RiskWarning] = []

    if m.maxDrawdown <= -0.25 {
        ws.append(RiskWarning(id: "max_drawdown", level: .red,
                              message: L10n.BacktestLab.warnMaxDrawdown))
    }
    if m.profitFactor < 1.0 {
        ws.append(RiskWarning(id: "profit_factor", level: .red,
                              message: L10n.BacktestLab.warnProfitFactor))
    }
    if m.totalTrades < 30 {
        ws.append(RiskWarning(id: "low_trades", level: .yellow,
                              message: L10n.BacktestLab.warnLowTrades))
    }
    if m.winRate < 0.35 {
        ws.append(RiskWarning(id: "low_winrate", level: .yellow,
                              message: L10n.BacktestLab.warnLowWinrate))
    }
    if m.sharpeRatio < 0 {
        ws.append(RiskWarning(id: "negative_sharpe", level: .yellow,
                              message: L10n.BacktestLab.warnNegativeSharpe))
    }

    // Sort: reds first, yellows second; same level preserves insertion order
    let reds = ws.filter { $0.level == .red }
    let yellows = ws.filter { $0.level == .yellow }
    return Array((reds + yellows).prefix(5))
}
