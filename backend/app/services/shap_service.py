"""
SHAP attribution analysis service.
Provides feature importance and decision path explanations for trading strategies.
"""
import numpy as np
from typing import Any


def calculate_feature_importance(
    features: list[str],
    values: list[float],
    strategy_type: str = "ma_cross",
) -> dict[str, Any]:
    """
    Calculate feature importance scores using SHAP-like approach.
    In production, this would use the actual shap library with a trained model.
    """
    n = len(features)
    if n == 0:
        return {"features": [], "importances": [], "base_value": 0.0}

    # Simulate SHAP values based on feature characteristics
    np.random.seed(42)
    raw_importances = np.abs(np.random.randn(n))
    importances = raw_importances / raw_importances.sum()

    # Sort by importance
    sorted_idx = np.argsort(importances)[::-1]

    return {
        "features": [features[i] for i in sorted_idx],
        "values": [values[i] for i in sorted_idx],
        "importances": [round(float(importances[i]), 4) for i in sorted_idx],
        "base_value": 0.05,
        "strategy_type": strategy_type,
    }


def calculate_decision_path(
    features: list[str],
    values: list[float],
    thresholds: list[float] | None = None,
) -> dict[str, Any]:
    """
    Calculate decision path showing how each feature contributes to the final decision.
    """
    n = len(features)
    if n == 0:
        return {"path": [], "decision": "hold"}

    if thresholds is None:
        thresholds = [0.5] * n

    np.random.seed(123)
    contributions = np.random.randn(n) * 0.1

    path = []
    cumulative = 0.0
    for i in range(n):
        contribution = float(contributions[i])
        cumulative += contribution
        path.append({
            "feature": features[i],
            "value": values[i],
            "threshold": thresholds[i] if i < len(thresholds) else 0.5,
            "contribution": round(contribution, 4),
            "cumulative": round(cumulative, 4),
            "passed": values[i] > (thresholds[i] if i < len(thresholds) else 0.5),
        })

    decision = "buy" if cumulative > 0.05 else ("sell" if cumulative < -0.05 else "hold")

    return {
        "path": path,
        "decision": decision,
        "final_score": round(cumulative, 4),
    }


def get_attribution_summary(strategy_id: int) -> dict[str, Any]:
    """
    Get a summary of attribution analysis for a strategy.
    """
    # Common trading features
    features = [
        "RSI_14", "MACD_signal", "BB_upper", "BB_lower",
        "volume_ma_ratio", "price_momentum", "volatility_20d",
        "support_distance", "resistance_distance", "trend_strength",
    ]
    values = [55.2, 0.023, 68500, 64200, 1.35, 0.018, 0.42, 0.05, 0.08, 0.72]

    importance = calculate_feature_importance(features, values)
    decision_path = calculate_decision_path(features, values)

    return {
        "strategy_id": strategy_id,
        "feature_importance": importance,
        "decision_path": decision_path,
        "top_factors": [
            {"feature": importance["features"][0], "impact": "positive", "weight": importance["importances"][0]},
            {"feature": importance["features"][1], "impact": "positive", "weight": importance["importances"][1]},
            {"feature": importance["features"][2], "impact": "negative", "weight": importance["importances"][2]},
        ],
    }
