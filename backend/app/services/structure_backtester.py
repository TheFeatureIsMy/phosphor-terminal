from __future__ import annotations

import logging
from collections import defaultdict
from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from app.services.structure.engine import StructureEngine
from app.services.structure.models import (
    MarketRegime, SweepState, StructureStatus, StructureDirection,
)
from app.services.structure.market_regime import classify_regime

logger = logging.getLogger(__name__)


@dataclass
class EventOutcome:
    event_type: str
    direction: str
    candle_index: int
    regime: str
    forward_returns: dict[int, float] = field(default_factory=dict)  # bars_ahead -> return_pct
    success: bool = False  # price moved in expected direction within N bars


@dataclass
class EventStats:
    event_type: str
    total_count: int = 0
    success_count: int = 0
    success_rate: float = 0.0
    avg_forward_return: dict[int, float] = field(default_factory=dict)
    by_regime: dict[str, dict] = field(default_factory=dict)


@dataclass
class StructureBacktestResult:
    total_bars: int = 0
    total_events: int = 0
    event_stats: dict[str, EventStats] = field(default_factory=dict)
    regime_distribution: dict[str, int] = field(default_factory=dict)
    outcomes: list[EventOutcome] = field(default_factory=list)


class StructureBacktester:
    """Pure-Python analytical backtester for structure events.

    Runs the StructureEngine on a full OHLCV DataFrame, then measures
    forward returns and success rates for each detected structure event
    (sweeps, FVGs, order blocks, BOS/CHoCH), segmented by market regime.
    """

    def __init__(self, timeframe: str = "5m", forward_bars: list[int] | None = None):
        self._timeframe = timeframe
        self._forward_bars = forward_bars or [5, 10, 20, 50]

    def run(self, df: pd.DataFrame) -> StructureBacktestResult:
        """Run the structure event backtest on *df*.

        Strategy:
        1. Classify market regime on a rolling basis for every bar.
        2. Run ``StructureEngine.analyze(df)`` once on the full dataset
           to collect all structure events (sweeps, FVGs, OBs, BOS/CHoCH).
        3. For each event, measure forward price returns and determine
           success/failure.
        4. Aggregate statistics per event type, segmented by market regime.
        """
        if len(df) < 60:
            return StructureBacktestResult(total_bars=len(df))

        result = StructureBacktestResult(total_bars=len(df))
        engine = StructureEngine(timeframe=self._timeframe, swing_lookback=3)
        closes = df["close"].values

        # ------------------------------------------------------------------
        # 1. Pre-compute per-bar market regime on a rolling window.
        # ------------------------------------------------------------------
        regime_window = 60
        bar_regimes: list[str] = []
        regime_counts: dict[str, int] = defaultdict(int)
        for i in range(len(df)):
            if i < regime_window:
                regime = MarketRegime.UNKNOWN.value
            else:
                regime = classify_regime(df.iloc[i - regime_window : i + 1]).value
            bar_regimes.append(regime)
            regime_counts[regime] += 1

        # ------------------------------------------------------------------
        # 2. Run the StructureEngine once on the full DataFrame.
        # ------------------------------------------------------------------
        snapshot = engine.analyze(df)

        # ------------------------------------------------------------------
        # 3. Collect events and measure forward returns.
        # ------------------------------------------------------------------
        all_outcomes: list[EventOutcome] = []
        seen_event_keys: set[tuple[str, int]] = set()

        # --- Sweeps ---
        for sweep in snapshot.active_sweeps:
            if sweep.state != SweepState.CONFIRMED_SWEEP:
                continue
            idx = sweep.candle_index
            if idx < 0 or idx >= len(closes):
                continue

            direction = (
                "bullish"
                if sweep.sweep_type == "sell_side_liquidity_sweep"
                else "bearish"
            )
            event_type = f"sweep_{sweep.sweep_type}"
            key = (event_type, idx)
            if key in seen_event_keys:
                continue
            seen_event_keys.add(key)

            outcome = self._measure_forward(
                closes, idx, direction, event_type, bar_regimes[idx],
            )
            if outcome:
                all_outcomes.append(outcome)

        # --- FVGs ---
        for fvg in snapshot.fvg_zones:
            idx = fvg.candle_index
            if idx < 0 or idx >= len(closes):
                continue

            direction = fvg.direction.value
            touch_label = "first_touch" if fvg.touched_count <= 1 else f"touch{fvg.touched_count}"
            event_type = f"fvg_{direction}_{touch_label}"
            key = (event_type, idx)
            if key in seen_event_keys:
                continue
            seen_event_keys.add(key)

            outcome = self._measure_forward(
                closes, idx, direction, event_type, bar_regimes[idx],
            )
            if outcome:
                all_outcomes.append(outcome)

        # --- Order Blocks ---
        for ob in snapshot.order_blocks:
            idx = ob.candle_index
            if idx < 0 or idx >= len(closes):
                continue

            direction = ob.direction.value
            touch_label = f"touch{ob.touched_count}" if ob.touched_count > 0 else "touch0"
            event_type = f"ob_{direction}_{touch_label}"
            key = (event_type, idx)
            if key in seen_event_keys:
                continue
            seen_event_keys.add(key)

            outcome = self._measure_forward(
                closes, idx, direction, event_type, bar_regimes[idx],
            )
            if outcome:
                all_outcomes.append(outcome)

        # --- BOS / CHoCH ---
        for brk in snapshot.structure_breaks:
            idx = brk.candle_index
            if idx < 0 or idx >= len(closes):
                continue

            direction = brk.direction.value
            event_type = f"{brk.break_type}_{direction}"
            key = (event_type, idx)
            if key in seen_event_keys:
                continue
            seen_event_keys.add(key)

            outcome = self._measure_forward(
                closes, idx, direction, event_type, bar_regimes[idx],
            )
            if outcome:
                all_outcomes.append(outcome)

        # ------------------------------------------------------------------
        # 4. Aggregate.
        # ------------------------------------------------------------------
        result.outcomes = all_outcomes
        result.total_events = len(all_outcomes)
        result.regime_distribution = dict(regime_counts)
        result.event_stats = self._aggregate_stats(all_outcomes)

        return result

    # ------------------------------------------------------------------
    # helpers
    # ------------------------------------------------------------------

    def _measure_forward(
        self,
        closes: np.ndarray,
        idx: int,
        direction: str,
        event_type: str,
        regime: str,
    ) -> EventOutcome | None:
        n = len(closes)
        if idx >= n - 1:
            return None

        entry_price = closes[idx]
        if entry_price <= 0:
            return None

        forward_returns: dict[int, float] = {}
        success = False

        for bars in self._forward_bars:
            future_idx = min(idx + bars, n - 1)
            ret = (closes[future_idx] - entry_price) / entry_price
            forward_returns[bars] = round(float(ret), 6)

            if direction == "bullish" and ret > 0.005:
                success = True
            elif direction == "bearish" and ret < -0.005:
                success = True

        return EventOutcome(
            event_type=event_type,
            direction=direction,
            candle_index=idx,
            regime=regime,
            forward_returns=forward_returns,
            success=success,
        )

    def _aggregate_stats(
        self, outcomes: list[EventOutcome],
    ) -> dict[str, EventStats]:
        groups: dict[str, list[EventOutcome]] = defaultdict(list)
        for o in outcomes:
            groups[o.event_type].append(o)

        stats: dict[str, EventStats] = {}
        for event_type, events in groups.items():
            total = len(events)
            successes = sum(1 for e in events if e.success)
            rate = successes / total if total > 0 else 0

            avg_returns: dict[int, float] = {}
            for bars in self._forward_bars:
                returns = [e.forward_returns.get(bars, 0) for e in events]
                avg_returns[bars] = (
                    round(float(np.mean(returns)), 6) if returns else 0
                )

            # Per-regime breakdown
            by_regime: dict[str, dict] = defaultdict(
                lambda: {"count": 0, "success": 0, "rate": 0.0},
            )
            for e in events:
                by_regime[e.regime]["count"] += 1
                if e.success:
                    by_regime[e.regime]["success"] += 1
            for r_data in by_regime.values():
                r_data["rate"] = (
                    round(r_data["success"] / r_data["count"], 4)
                    if r_data["count"] > 0
                    else 0.0
                )

            stats[event_type] = EventStats(
                event_type=event_type,
                total_count=total,
                success_count=successes,
                success_rate=round(rate, 4),
                avg_forward_return=avg_returns,
                by_regime=dict(by_regime),
            )

        return stats
