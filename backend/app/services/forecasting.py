from __future__ import annotations

from datetime import datetime, timedelta, timezone


def deterministic_forecast(symbol: str, model: str, horizon: str) -> dict:
    days = 14 if horizon.endswith("14d") else 7
    base = 100 + (sum(ord(ch) for ch in symbol) % 50)
    model_bias = 1.2 if model.lower() == "timesfm" else 0.8
    now = datetime.now(timezone.utc)
    points = []
    for i in range(days):
        value = base + i * model_bias + ((i % 3) - 1) * 0.7
        points.append({
            "date": (now + timedelta(days=i + 1)).strftime("%Y-%m-%d"),
            "value": round(value, 4),
        })
    return {"points": points, "confidence": 0.62 if model.lower() == "timesfm" else 0.58}
