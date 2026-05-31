from __future__ import annotations

import re


def _clamp(value: float) -> float:
    return round(max(0.0, min(5.0, value)), 4)


def score_signal_text(symbol: str | None, direction: str | None, content: str | None) -> dict[str, float]:
    text = (content or "").strip()
    lower = text.lower()

    verifiability = 0.5
    if symbol:
        verifiability += 1.0
    if direction in {"long", "short", "buy", "sell", "hold"}:
        verifiability += 1.0
    if re.search(r"(target|目标|tp)\D{0,12}\d+", lower):
        verifiability += 1.0
    if re.search(r"(stop|止损|sl)\D{0,12}\d+", lower):
        verifiability += 1.0

    evidence = min(5.0, len(text) / 180.0)
    for keyword in ("because", "risk", "earnings", "momentum", "valuation", "liquidity", "因为", "风险"):
        if keyword in lower:
            evidence += 0.45

    specificity = 0.5
    if symbol:
        specificity += 1.0
    if re.search(r"\d+(\.\d+)?%?", text):
        specificity += 1.0
    if len(text) > 120:
        specificity += 1.0

    novelty = 3.0
    risk = 1.0
    if "stop" in lower or "止损" in lower:
        risk += 1.0
    if "position" in lower or "仓位" in lower:
        risk += 1.0

    overall = (
        _clamp(verifiability) * 0.3
        + _clamp(evidence) * 0.25
        + _clamp(specificity) * 0.2
        + _clamp(novelty) * 0.1
        + _clamp(risk) * 0.15
    )

    return {
        "verifiability_score": _clamp(verifiability),
        "evidence_score": _clamp(evidence),
        "specificity_score": _clamp(specificity),
        "novelty_score": _clamp(novelty),
        "risk_score": _clamp(risk),
        "overall_score": _clamp(overall),
    }
