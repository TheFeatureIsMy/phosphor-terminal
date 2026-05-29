"""SHAP attribution analysis service.

Uses SHAP + LightGBM for real feature importance when available.
Falls back to heuristic when dependencies are missing or insufficient data.
"""
from __future__ import annotations

from typing import Any, Optional


class SHAPService:
    """SHAP-based feature importance with lazy model training."""

    _model = None
    _explainer = None
    _feature_names: list[str] = []
    _load_failed = False

    @property
    def available(self) -> bool:
        try:
            import shap  # noqa: F401
            import lightgbm  # noqa: F401
            return True
        except ImportError:
            return False

    def _ensure_model(self, features: list[str], values: list[float]) -> bool:
        """Try to train model from trade data. Returns True if model is ready."""
        if self._model is not None:
            return True
        if self._load_failed:
            return False

        try:
            import lightgbm as lgb
            import shap
            import numpy as np
            import pandas as pd

            # Try to get training data from FreqtradeDB
            training_data = self._load_training_data()
            if training_data is None or len(training_data) < 50:
                self._load_failed = True
                return False

            X, y = training_data
            self._feature_names = list(X.columns)

            dataset = lgb.Dataset(X, label=y)
            params = {
                "objective": "binary",
                "metric": "auc",
                "verbosity": -1,
                "num_leaves": 31,
                "feature_fraction": 0.8,
                "bagging_fraction": 0.8,
                "bagging_freq": 5,
            }
            self._model = lgb.train(params, dataset, num_boost_round=100)
            self._explainer = shap.TreeExplainer(self._model)
            return True

        except Exception:
            self._load_failed = True
            return False

    def _load_training_data(self) -> Optional[tuple]:
        """Load training data from FreqtradeDB trade history."""
        try:
            import pandas as pd
            import numpy as np
            from app.services.freqtrade_db import freqtrade_db

            if not freqtrade_db.is_available():
                return None

            engine = freqtrade_db.engine
            if engine is None:
                return None

            # Get recent trades
            df = pd.read_sql(
                "SELECT open_rate, close_rate, close_profit, stake_amount, "
                "open_date, close_date FROM trades WHERE is_open=0 "
                "ORDER BY close_date DESC LIMIT 500",
                engine,
            )
            if len(df) < 50:
                return None

            # Engineer features
            df["return_pct"] = (df["close_rate"] - df["open_rate"]) / df["open_rate"]
            df["trade_duration"] = pd.to_datetime(df["close_date"]) - pd.to_datetime(df["open_date"])
            df["duration_hours"] = df["trade_duration"].dt.total_seconds() / 3600

            feature_cols = ["open_rate", "stake_amount", "duration_hours", "return_pct"]
            X = df[feature_cols].fillna(0)
            y = (df["close_profit"] > 0).astype(int)

            return X, y

        except Exception:
            return None

    def calculate_feature_importance(
        self,
        features: list[str],
        values: list[float],
        strategy_type: str = "ma_cross",
    ) -> dict[str, Any]:
        """Calculate feature importance using SHAP if available, else heuristic."""
        n = len(features)
        if n == 0:
            return {"features": [], "importances": [], "base_value": 0.0, "model": "none"}

        # Try real SHAP
        if self._ensure_model(features, values):
            try:
                import numpy as np
                import pandas as pd

                # Map input features to model features (best effort)
                input_dict = dict(zip(features, values))
                model_input = pd.DataFrame(
                    [[input_dict.get(f, 0.0) for f in self._feature_names]],
                    columns=self._feature_names,
                )
                shap_values = self._explainer.shap_values(model_input)
                # shap_values is list [class_0, class_1] for binary classification
                if isinstance(shap_values, list):
                    sv = shap_values[1][0]
                else:
                    sv = shap_values[0]

                abs_sv = np.abs(sv)
                if abs_sv.sum() > 0:
                    importances = abs_sv / abs_sv.sum()
                else:
                    importances = np.ones(len(sv)) / len(sv)

                sorted_idx = np.argsort(importances)[::-1]
                return {
                    "features": [self._feature_names[i] for i in sorted_idx],
                    "values": [float(values[features.index(self._feature_names[i])]) if self._feature_names[i] in features else 0.0 for i in sorted_idx],
                    "importances": [round(float(importances[i]), 4) for i in sorted_idx],
                    "base_value": round(float(self._explainer.expected_value[1] if isinstance(self._explainer.expected_value, (list, np.ndarray)) else self._explainer.expected_value), 4),
                    "strategy_type": strategy_type,
                    "model": "shap_lightgbm",
                }
            except Exception:
                pass

        # Heuristic fallback
        return self._heuristic_importance(features, values, strategy_type)

    def _heuristic_importance(
        self,
        features: list[str],
        values: list[float],
        strategy_type: str,
    ) -> dict[str, Any]:
        """Deterministic heuristic importance based on feature name patterns."""
        import numpy as np

        n = len(features)
        weights = []
        for f in features:
            fl = f.lower()
            if "rsi" in fl:
                weights.append(0.15)
            elif "macd" in fl:
                weights.append(0.13)
            elif "volume" in fl:
                weights.append(0.11)
            elif "momentum" in fl:
                weights.append(0.12)
            elif "volatility" in fl:
                weights.append(0.10)
            elif "bb" in fl or "bollinger" in fl:
                weights.append(0.09)
            elif "support" in fl or "resistance" in fl:
                weights.append(0.08)
            elif "trend" in fl:
                weights.append(0.07)
            else:
                weights.append(0.05)

        w = np.array(weights)
        importances = w / w.sum()
        sorted_idx = np.argsort(importances)[::-1]

        return {
            "features": [features[i] for i in sorted_idx],
            "values": [values[i] for i in sorted_idx],
            "importances": [round(float(importances[i]), 4) for i in sorted_idx],
            "base_value": 0.05,
            "strategy_type": strategy_type,
            "model": "heuristic",
        }

    def calculate_decision_path(
        self,
        features: list[str],
        values: list[float],
        thresholds: Optional[list[float]] = None,
    ) -> dict[str, Any]:
        """Calculate decision path with feature contributions."""
        n = len(features)
        if n == 0:
            return {"path": [], "decision": "hold", "model": "none"}

        if thresholds is None:
            thresholds = [0.5] * n

        # Use SHAP values as contributions if available
        contributions = []
        if self._ensure_model(features, values):
            try:
                import pandas as pd
                import numpy as np

                input_dict = dict(zip(features, values))
                model_input = pd.DataFrame(
                    [[input_dict.get(f, 0.0) for f in self._feature_names]],
                    columns=self._feature_names,
                )
                shap_values = self._explainer.shap_values(model_input)
                if isinstance(shap_values, list):
                    sv = shap_values[1][0]
                else:
                    sv = shap_values[0]

                for i, f in enumerate(features):
                    if f in self._feature_names:
                        idx = self._feature_names.index(f)
                        contributions.append(float(sv[idx]))
                    else:
                        contributions.append(0.0)
            except Exception:
                contributions = [0.0] * n
        else:
            # Heuristic contributions
            import numpy as np
            np.random.seed(123)
            contributions = list(np.random.randn(n) * 0.1)

        path = []
        cumulative = 0.0
        for i in range(n):
            contribution = contributions[i] if i < len(contributions) else 0.0
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
            "model": "shap_lightgbm" if self._model else "heuristic",
        }


# Module-level singleton
shap_service = SHAPService()


# Keep backward-compatible function API
def calculate_feature_importance(features, values, strategy_type="ma_cross"):
    return shap_service.calculate_feature_importance(features, values, strategy_type)

def calculate_decision_path(features, values, thresholds=None):
    return shap_service.calculate_decision_path(features, values, thresholds)

def get_attribution_summary(strategy_id: int) -> dict[str, Any]:
    features = [
        "RSI_14", "MACD_signal", "BB_upper", "BB_lower",
        "volume_ma_ratio", "price_momentum", "volatility_20d",
        "support_distance", "resistance_distance", "trend_strength",
    ]
    values = [55.2, 0.023, 68500, 64200, 1.35, 0.018, 0.42, 0.05, 0.08, 0.72]
    importance = shap_service.calculate_feature_importance(features, values)
    decision_path = shap_service.calculate_decision_path(features, values)
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
