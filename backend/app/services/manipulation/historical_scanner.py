"""Historical manipulation scanner — scans price history to find and label past manipulation events."""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.services.manipulation.features import compute_all_features
from app.services.manipulation.classifier import ManipulationPatternClassifier
from app.services.manipulation.lifecycle import ManipulationLifecycleTracker

logger = logging.getLogger(__name__)


@dataclass
class ScanResult:
    symbol: str
    market: str
    scanned_candles: int
    events_detected: int
    confirmed_cases: int
    cases: list[dict] = field(default_factory=list)


class HistoricalManipulationScanner:
    """Scan historical OHLCV data to discover past manipulation events."""

    def __init__(self):
        self.classifier = ManipulationPatternClassifier()
        self.lifecycle = ManipulationLifecycleTracker()

    def scan(
        self, candles: list[dict], symbol: str = "", market: str = "crypto",
        window_size: int = 30, step: int = 10, anomaly_threshold: float = 40.0
    ) -> ScanResult:
        """Scan candle history with sliding window. Returns detected manipulation events."""
        if len(candles) < window_size:
            return ScanResult(symbol=symbol, market=market, scanned_candles=len(candles),
                              events_detected=0, confirmed_cases=0)

        # Step 1: Sliding window anomaly detection
        anomaly_points = []
        for i in range(0, len(candles) - window_size, step):
            window = candles[i:i + window_size]
            features = compute_all_features(window)
            # Aggregate anomaly: average of all non-zero feature scores
            scores = [v for v in features.values() if v > 0]
            avg_score = sum(scores) / len(scores) if scores else 0
            if avg_score > anomaly_threshold:
                anomaly_points.append({
                    "index": i + window_size,
                    "score": avg_score,
                    "features": features,
                })

        # Step 2: Cluster nearby anomaly points into events
        events = self._cluster_anomalies(anomaly_points, max_gap_indices=window_size)

        # Step 3: Classify each event and build cases
        cases = []
        for event in events:
            # Get the features from the peak anomaly point
            peak = max(event, key=lambda p: p["score"])
            patterns = self.classifier.classify(peak["features"])
            if not patterns:
                continue
            primary = patterns[0]

            # Measure outcome: price change from event start to end + lookforward
            start_idx = event[0]["index"]
            end_idx = event[-1]["index"]
            lookforward = min(end_idx + window_size * 3, len(candles) - 1)

            event_prices = [candles[i]["close"] for i in range(start_idx, min(lookforward + 1, len(candles)))]
            outcome = self._measure_outcome(event_prices) if len(event_prices) > 5 else {}

            # Retrospective lifecycle labeling
            features_timeline = []
            for i in range(start_idx, min(lookforward + 1, len(candles)), step):
                w = candles[max(0, i - window_size):i]
                if len(w) >= 10:
                    features_timeline.append(compute_all_features(w))
            stages = self.lifecycle.retrospective_label(event_prices, features_timeline)

            case = {
                "symbol": symbol,
                "market": market,
                "manipulation_type": primary.manipulation_type,
                "type_label": primary.type_label,
                "confidence": primary.confidence,
                "evidence": primary.evidence,
                "timeline": stages,
                "outcome": outcome,
                "start_index": start_idx,
                "end_index": end_idx,
                "peak_anomaly_score": peak["score"],
                "peak_features": peak["features"],
            }

            # Verify: only confirm if outcome shows significant price movement
            if outcome.get("was_manipulation", False):
                cases.append(case)

        return ScanResult(
            symbol=symbol, market=market, scanned_candles=len(candles),
            events_detected=len(events), confirmed_cases=len(cases), cases=cases,
        )

    def _cluster_anomalies(
        self, points: list[dict], max_gap_indices: int = 30
    ) -> list[list[dict]]:
        """Group anomaly points that are close together into events."""
        if not points:
            return []
        clusters: list[list[dict]] = [[points[0]]]
        for p in points[1:]:
            if p["index"] - clusters[-1][-1]["index"] <= max_gap_indices:
                clusters[-1].append(p)
            else:
                clusters.append([p])
        # Filter: at least 2 anomaly points to be an event
        return [c for c in clusters if len(c) >= 2]

    def _measure_outcome(self, prices: list[float]) -> dict:
        """Measure the outcome of a price series to verify manipulation."""
        if len(prices) < 5:
            return {"was_manipulation": False}
        start = prices[0]
        peak = max(prices)
        trough_after_peak = min(prices[prices.index(peak):]) if prices.index(peak) < len(prices) - 1 else peak
        peak_change = (peak - start) / start if start > 0 else 0
        collapse = (trough_after_peak - peak) / peak if peak > 0 else 0
        # Confirmed manipulation: significant pump (>20%) followed by significant dump (>30% from peak)
        was_manip = peak_change > 0.20 and collapse < -0.30
        return {
            "was_manipulation": was_manip,
            "peak_price_change_pct": round(peak_change * 100, 2),
            "collapse_depth_pct": round(collapse * 100, 2),
            "start_price": start,
            "peak_price": peak,
            "trough_price": trough_after_peak,
        }
