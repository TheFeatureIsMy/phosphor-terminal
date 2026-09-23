"""GrowthAttributionService — SHAP feature attribution from real trade data.

Joins FeatureSnapshot (indicators at decision time) with ExecutionTrade (outcomes)
to compute which features drove winning vs losing trades.
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun
from app.domain.feature import FeatureSnapshot
from app.domain.order import ExecutionTrade
from app.domain.trade_intent import TradeIntent

logger = logging.getLogger(__name__)


@dataclass
class AttributionResult:
    total_trades_analyzed: int = 0
    feature_importances: list[dict[str, Any]] = field(default_factory=list)
    win_drivers: list[dict[str, Any]] = field(default_factory=list)
    loss_drivers: list[dict[str, Any]] = field(default_factory=list)
    model_type: str = "heuristic"
    sufficient_data: bool = False


class GrowthAttributionService:
    """Computes SHAP-based feature attribution from real trade + snapshot data."""

    def __init__(self, db: Session):
        self._db = db

    def compute_attribution(
        self, strategy_run_id: uuid.UUID | None = None,
        strategy_version_id: uuid.UUID | None = None,
        min_trades: int = 10,
    ) -> AttributionResult:
        """Compute feature attribution for a strategy's trades."""
        # 1. Get closed trades with feature snapshots
        trade_features = self._load_trade_features(strategy_run_id, strategy_version_id)

        if len(trade_features) < min_trades:
            return AttributionResult(
                total_trades_analyzed=len(trade_features),
                sufficient_data=False,
                model_type="insufficient_data",
            )

        # 2. Build feature matrix (X) and label vector (y)
        feature_names, X, y = self._build_matrix(trade_features)

        if not feature_names:
            return AttributionResult(
                total_trades_analyzed=len(trade_features),
                sufficient_data=False,
                model_type="no_features",
            )

        # 3. Try SHAP + LightGBM, fall back to heuristic
        result = self._run_attribution(feature_names, X, y)
        result.total_trades_analyzed = len(trade_features)
        result.sufficient_data = True
        return result

    def _load_trade_features(
        self,
        strategy_run_id: uuid.UUID | None,
        strategy_version_id: uuid.UUID | None,
    ) -> list[dict]:
        """Load trades joined with their feature snapshots."""
        # Get closed trades
        stmt = select(ExecutionTrade).where(ExecutionTrade.status == "closed")
        if strategy_run_id:
            stmt = stmt.where(ExecutionTrade.strategy_run_id == strategy_run_id)

        trades = list(self._db.scalars(stmt).all())
        if not trades:
            return []

        # For each trade, try to find its FeatureSnapshot via trade_intent
        results = []
        for trade in trades:
            snapshot = self._find_snapshot_for_trade(trade, strategy_version_id)
            if snapshot and snapshot.technical_features:
                results.append({
                    "trade": trade,
                    "features": snapshot.technical_features,
                    "is_win": float(trade.profit_abs or 0) > 0,
                })

        return results

    def _find_snapshot_for_trade(
        self, trade: ExecutionTrade, strategy_version_id: uuid.UUID | None,
    ) -> FeatureSnapshot | None:
        """Find the FeatureSnapshot associated with a trade."""
        # Try via source_order_id → trade_intent_id → feature_snapshot
        if trade.source_system == "pulsedesk" and trade.source_trade_id:
            # Extract intent_id if it was stored in source
            intent_id_str = trade.source_trade_id.replace("ft-", "")
            try:
                intent_id = uuid.UUID(intent_id_str)
                snap = self._db.scalars(
                    select(FeatureSnapshot).where(
                        FeatureSnapshot.trade_intent_id == intent_id
                    ).limit(1)
                ).first()
                if snap:
                    return snap
            except (ValueError, TypeError):
                pass

        # Fallback: find snapshot by symbol + time proximity
        if trade.opened_at and trade.symbol:
            from datetime import timedelta
            window_start = trade.opened_at - timedelta(minutes=5)
            window_end = trade.opened_at + timedelta(minutes=5)

            filters = [
                FeatureSnapshot.symbol == trade.symbol,
                FeatureSnapshot.snapshot_at >= window_start,
                FeatureSnapshot.snapshot_at <= window_end,
            ]
            if strategy_version_id:
                filters.append(FeatureSnapshot.strategy_version_id == strategy_version_id)

            snap = self._db.scalars(
                select(FeatureSnapshot).where(and_(*filters))
                .order_by(FeatureSnapshot.snapshot_at.desc())
                .limit(1)
            ).first()
            return snap

        return None

    def _build_matrix(self, trade_features: list[dict]) -> tuple[list[str], list[list[float]], list[int]]:
        """Build feature matrix X and label y from trade data."""
        # Collect all feature names across all snapshots
        all_keys: set[str] = set()
        for tf in trade_features:
            all_keys.update(tf["features"].keys())

        # Filter to numeric features only
        feature_names = sorted(all_keys)

        X: list[list[float]] = []
        y: list[int] = []
        valid_features: list[str] = []

        # First pass: determine which features are consistently numeric
        for name in feature_names:
            is_numeric = True
            for tf in trade_features[:5]:
                val = tf["features"].get(name)
                if val is not None and not isinstance(val, (int, float)):
                    is_numeric = False
                    break
            if is_numeric:
                valid_features.append(name)

        # Build matrix
        for tf in trade_features:
            row = []
            for name in valid_features:
                val = tf["features"].get(name, 0)
                row.append(float(val) if val is not None else 0.0)
            X.append(row)
            y.append(1 if tf["is_win"] else 0)

        return valid_features, X, y

    def _run_attribution(
        self, feature_names: list[str], X: list[list[float]], y: list[int],
    ) -> AttributionResult:
        """Run SHAP if available, otherwise heuristic."""
        try:
            return self._shap_attribution(feature_names, X, y)
        except Exception:
            logger.debug("SHAP unavailable, using heuristic attribution")
            return self._heuristic_attribution(feature_names, X, y)

    def _shap_attribution(
        self, feature_names: list[str], X: list[list[float]], y: list[int],
    ) -> AttributionResult:
        import numpy as np
        import lightgbm as lgb
        import shap

        X_np = np.array(X)
        y_np = np.array(y)

        dataset = lgb.Dataset(X_np, label=y_np, feature_name=feature_names)
        params = {
            "objective": "binary",
            "metric": "auc",
            "verbosity": -1,
            "num_leaves": 15,
            "min_data_in_leaf": 3,
            "feature_fraction": 0.8,
        }
        model = lgb.train(params, dataset, num_boost_round=50)
        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(X_np)

        if isinstance(shap_values, list):
            sv = np.array(shap_values[1])
        else:
            sv = np.array(shap_values)

        # Global importance
        mean_abs = np.abs(sv).mean(axis=0)
        total = mean_abs.sum()
        importances = mean_abs / total if total > 0 else np.ones(len(feature_names)) / len(feature_names)

        sorted_idx = np.argsort(importances)[::-1]
        feature_importances = [
            {"feature": feature_names[i], "importance": round(float(importances[i]), 4)}
            for i in sorted_idx[:15]
        ]

        # Win/loss drivers: mean SHAP for wins vs losses
        win_mask = y_np == 1
        loss_mask = y_np == 0

        win_drivers = []
        loss_drivers = []

        if win_mask.sum() > 0:
            win_mean = sv[win_mask].mean(axis=0)
            win_sorted = np.argsort(win_mean)[::-1]
            win_drivers = [
                {"feature": feature_names[i], "contribution": round(float(win_mean[i]), 4)}
                for i in win_sorted[:5] if win_mean[i] > 0
            ]

        if loss_mask.sum() > 0:
            loss_mean = sv[loss_mask].mean(axis=0)
            loss_sorted = np.argsort(loss_mean)
            loss_drivers = [
                {"feature": feature_names[i], "contribution": round(float(loss_mean[i]), 4)}
                for i in loss_sorted[:5] if loss_mean[i] < 0
            ]

        return AttributionResult(
            feature_importances=feature_importances,
            win_drivers=win_drivers,
            loss_drivers=loss_drivers,
            model_type="shap_lightgbm",
        )

    def _heuristic_attribution(
        self, feature_names: list[str], X: list[list[float]], y: list[int],
    ) -> AttributionResult:
        """Simple correlation-based attribution when SHAP is unavailable."""
        import statistics

        n_features = len(feature_names)
        n_samples = len(y)

        if n_features == 0 or n_samples == 0:
            return AttributionResult(model_type="heuristic")

        # Compute mean feature values for wins vs losses
        win_means = [0.0] * n_features
        loss_means = [0.0] * n_features
        win_count = sum(y)
        loss_count = n_samples - win_count

        for i, row in enumerate(X):
            for j, val in enumerate(row):
                if y[i] == 1:
                    win_means[j] += val
                else:
                    loss_means[j] += val

        if win_count > 0:
            win_means = [v / win_count for v in win_means]
        if loss_count > 0:
            loss_means = [v / loss_count for v in loss_means]

        # Importance = abs(win_mean - loss_mean) normalized
        diffs = [abs(win_means[j] - loss_means[j]) for j in range(n_features)]
        total_diff = sum(diffs)
        importances = [d / total_diff if total_diff > 0 else 1.0 / n_features for d in diffs]

        sorted_idx = sorted(range(n_features), key=lambda i: importances[i], reverse=True)
        feature_importances = [
            {"feature": feature_names[i], "importance": round(importances[i], 4)}
            for i in sorted_idx[:15]
        ]

        # Win/loss drivers by direction of difference
        win_drivers = [
            {"feature": feature_names[i], "contribution": round(win_means[i] - loss_means[i], 4)}
            for i in sorted_idx[:5]
            if win_means[i] > loss_means[i]
        ]
        loss_drivers = [
            {"feature": feature_names[i], "contribution": round(loss_means[i] - win_means[i], 4)}
            for i in sorted_idx[:5]
            if loss_means[i] > win_means[i]
        ]

        return AttributionResult(
            feature_importances=feature_importances,
            win_drivers=win_drivers,
            loss_drivers=loss_drivers,
            model_type="heuristic",
        )
