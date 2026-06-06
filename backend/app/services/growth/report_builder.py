"""Report builder — generates GrowthReport from trade metrics."""
from __future__ import annotations

from app.schemas.growth import TradeMetrics, Finding


def generate_findings(metrics: TradeMetrics) -> list[Finding]:
    findings: list[Finding] = []

    if metrics.total_trades == 0:
        findings.append(Finding(
            category="pattern",
            description="No trades in the review period",
        ))
        return findings

    if metrics.win_rate >= 0.6:
        findings.append(Finding(
            category="strength",
            description=f"Strong win rate at {metrics.win_rate:.1%}",
            evidence={"win_rate": metrics.win_rate, "total_trades": metrics.total_trades},
        ))
    elif metrics.win_rate < 0.4 and metrics.total_trades >= 5:
        findings.append(Finding(
            category="weakness",
            description=f"Low win rate at {metrics.win_rate:.1%}",
            evidence={"win_rate": metrics.win_rate, "total_trades": metrics.total_trades},
        ))

    if metrics.profit_factor >= 2.0:
        findings.append(Finding(
            category="strength",
            description=f"Excellent profit factor of {metrics.profit_factor:.2f}",
            evidence={"profit_factor": metrics.profit_factor},
        ))
    elif metrics.profit_factor < 1.0 and metrics.profit_factor > 0:
        findings.append(Finding(
            category="risk",
            description=f"Profit factor below 1.0 ({metrics.profit_factor:.2f}) — net losing strategy",
            evidence={"profit_factor": metrics.profit_factor},
        ))

    if metrics.max_drawdown_pct > 10.0:
        findings.append(Finding(
            category="risk",
            description=f"High max drawdown at {metrics.max_drawdown_pct:.1f}%",
            evidence={"max_drawdown_pct": metrics.max_drawdown_pct},
        ))

    if metrics.avg_hold_duration_hours > 0 and metrics.avg_hold_duration_hours < 0.5:
        findings.append(Finding(
            category="pattern",
            description=f"Very short average hold time ({metrics.avg_hold_duration_hours:.1f}h) — possible scalping",
            evidence={"avg_hold_duration_hours": metrics.avg_hold_duration_hours},
        ))

    return findings


def generate_suggestions(metrics: TradeMetrics, findings: list[Finding]) -> list[str]:
    suggestions: list[str] = []

    risk_findings = [f for f in findings if f.category == "risk"]
    weakness_findings = [f for f in findings if f.category == "weakness"]

    if any(f for f in risk_findings if "drawdown" in f.description.lower()):
        suggestions.append("Consider tightening stop-loss or reducing position size to limit drawdown")

    if any(f for f in weakness_findings if "win rate" in f.description.lower()):
        suggestions.append("Review entry conditions — low win rate may indicate weak signal quality")

    if metrics.profit_factor > 0 and metrics.profit_factor < 1.0:
        suggestions.append("Net losing strategy — consider pausing and reviewing entry/exit logic")

    if metrics.avg_loss_pct != 0 and metrics.avg_profit_pct != 0:
        rr = abs(metrics.avg_profit_pct / metrics.avg_loss_pct) if metrics.avg_loss_pct != 0 else 0
        if rr < 1.0 and rr > 0:
            suggestions.append(f"Risk/reward ratio is {rr:.2f} — consider widening take-profit or tightening stop-loss")

    return suggestions
