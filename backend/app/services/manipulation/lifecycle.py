"""Manipulation lifecycle state machine — tracks manipulation events through stages."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class LifecycleStage(str, Enum):
    SUSPECTED = "suspected"
    ACCUMULATE = "accumulate"
    MARKUP = "markup"
    DISTRIBUTE = "distribute"
    COLLAPSE = "collapse"
    COMPLETED = "completed"
    FALSE_ALARM = "false_alarm"


@dataclass
class TradingSignal:
    action: str        # AMBUSH / RIDE / EXIT_OR_SHORT / AVOID / WATCH / CAUTION / EXIT
    direction: str     # long / short / none
    sizing: str        # small / medium / reduce / none
    stop_loss: str     # tight / trailing / none
    rationale: str
    risk_level: str    # low / medium / high / extreme

    def to_dict(self) -> dict:
        return {
            "action": self.action,
            "direction": self.direction,
            "sizing": self.sizing,
            "stop_loss": self.stop_loss,
            "rationale": self.rationale,
            "risk_level": self.risk_level,
        }


# Trading signals per stage and user profile
AGGRESSIVE_SIGNALS: dict[str, TradingSignal] = {
    "suspected": TradingSignal("WATCH", "none", "none", "none",
        "Suspected manipulation — monitoring for confirmation", "medium"),
    "accumulate": TradingSignal("AMBUSH", "long", "small", "tight",
        "Accumulation phase detected — small position, tight stop", "high"),
    "markup": TradingSignal("RIDE", "long", "medium", "trailing",
        "Markup confirmed — ride with trailing stop, don't get shaken out", "medium"),
    "distribute": TradingSignal("EXIT_OR_SHORT", "short", "reduce", "tight",
        "Distribution signals — exit longs or initiate short, high alert", "high"),
    "collapse": TradingSignal("AVOID", "none", "none", "none",
        "Collapse in progress — do not attempt to catch falling knife", "extreme"),
}

CONSERVATIVE_SIGNALS: dict[str, TradingSignal] = {
    "suspected": TradingSignal("WATCH", "none", "none", "none",
        "Manipulation suspected — observe only", "medium"),
    "accumulate": TradingSignal("WATCH", "none", "none", "none",
        "Possible accumulation — avoid this asset", "medium"),
    "markup": TradingSignal("CAUTION", "none", "none", "none",
        "Manipulation markup underway — if holding, set strict risk limits", "high"),
    "distribute": TradingSignal("EXIT", "none", "none", "none",
        "Distribution phase — exit all positions immediately", "high"),
    "collapse": TradingSignal("AVOID", "none", "none", "none",
        "Collapse underway — absolute avoidance", "extreme"),
}


class ManipulationLifecycleTracker:
    """State machine tracking manipulation events through their lifecycle."""

    def evaluate_transition(
        self, current_stage: str, features: dict[str, float]
    ) -> str:
        """Evaluate whether the current features warrant a stage transition."""

        if current_stage == LifecycleStage.SUSPECTED:
            # Confirm accumulation: consolidation + volume decline
            if features.get("consolidation_score", 0) > 50:
                return LifecycleStage.ACCUMULATE
            # Could also jump to markup if already breaking out
            if features.get("breakout_velocity", 0) > 60:
                return LifecycleStage.MARKUP

        elif current_stage == LifecycleStage.ACCUMULATE:
            # Transition to markup: breakout velocity + volume surge
            if (features.get("breakout_velocity", 0) > 50 and
                    features.get("volume_zscore", 0) > 40):
                return LifecycleStage.MARKUP
            # False alarm: consolidation weakens, no breakout after extended period
            if features.get("consolidation_score", 0) < 20:
                return LifecycleStage.FALSE_ALARM

        elif current_stage == LifecycleStage.MARKUP:
            # Transition to distribution: volume-price divergence
            if (features.get("distribution_signature", 0) > 50 and
                    features.get("volume_price_divergence", 0) > 40):
                return LifecycleStage.DISTRIBUTE
            # False alarm: price returns to pre-markup level
            if features.get("dump_then_recover", 0) < 10 and features.get("breakout_velocity", 0) < 10:
                return LifecycleStage.FALSE_ALARM

        elif current_stage == LifecycleStage.DISTRIBUTE:
            # Transition to collapse: sharp price drop
            if (features.get("pump_then_dump", 0) > 60 and
                    features.get("volume_zscore", 0) > 50):
                return LifecycleStage.COLLAPSE

        elif current_stage == LifecycleStage.COLLAPSE:
            # Mark as completed when volatility subsides
            if (features.get("volume_zscore", 0) < 20 and
                    features.get("price_range_spike", 0) < 20):
                return LifecycleStage.COMPLETED

        return current_stage  # No transition

    def generate_signal(
        self, stage: str, user_profile: str = "conservative"
    ) -> TradingSignal:
        """Generate trading signal based on lifecycle stage and user profile."""
        signals = AGGRESSIVE_SIGNALS if user_profile == "aggressive" else CONSERVATIVE_SIGNALS
        return signals.get(stage, CONSERVATIVE_SIGNALS["suspected"])

    def retrospective_label(
        self, price_series: list[float], features_timeline: list[dict[str, float]]
    ) -> list[dict]:
        """Label lifecycle stages retrospectively using complete price history.
        Used for historical case training — we have 'god view' of the outcome."""
        if not price_series or len(price_series) < 10:
            return []

        n = len(price_series)
        peak_idx = price_series.index(max(price_series))
        collapse_low_idx = peak_idx + price_series[peak_idx:].index(min(price_series[peak_idx:]))

        # Determine stage boundaries
        # Accumulate: start → acceleration point (before peak)
        accu_end = max(1, peak_idx // 3)
        # Markup: acceleration → peak
        markup_end = peak_idx
        # Distribute: around peak (peak ± 10%)
        dist_end = min(n - 1, peak_idx + max(1, (collapse_low_idx - peak_idx) // 3))
        # Collapse: after distribution → low

        stages = []
        if accu_end > 0:
            stages.append({
                "stage": "accumulate",
                "start_idx": 0,
                "end_idx": accu_end,
                "features": features_timeline[accu_end] if accu_end < len(features_timeline) else {},
            })
        if markup_end > accu_end:
            stages.append({
                "stage": "markup",
                "start_idx": accu_end,
                "end_idx": markup_end,
                "features": features_timeline[markup_end] if markup_end < len(features_timeline) else {},
            })
        if dist_end > markup_end:
            stages.append({
                "stage": "distribute",
                "start_idx": markup_end,
                "end_idx": dist_end,
                "features": features_timeline[dist_end] if dist_end < len(features_timeline) else {},
            })
        if collapse_low_idx > dist_end:
            stages.append({
                "stage": "collapse",
                "start_idx": dist_end,
                "end_idx": collapse_low_idx,
                "features": features_timeline[collapse_low_idx] if collapse_low_idx < len(features_timeline) else {},
            })

        return stages
