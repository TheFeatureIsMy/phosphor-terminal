"""MTF Temporal Guard Service — §6 Cross-Timeframe Structure Defense.

Evaluates whether a low-timeframe (fast) price action has violated a
high-timeframe (slow) structure zone. The state machine tracks the
violation lifecycle until the slow candle closes and confirms or
invalidates the break.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

import pandas as pd

from app.domain.enums import MTFGuardState, MTFGuardAction
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.structure.timeframe import (
    TIMEFRAME_RANK, TIMEFRAME_MINUTES,
    can_invalidate_structure, get_rank, get_minutes,
)

logger = logging.getLogger(__name__)


# Default violation policy mapping
DEFAULT_VIOLATION_POLICY: dict[str, str] = {
    "temporary_violation": "block_entry",
    "reclaim_pending": "require_confirmation",
    "confirmed_reclaim": "allow",
    "confirmed_break": "invalidate",
}


class MTFTemporalGuardService:
    """State machine for multi-timeframe structure defense.

    The guard watches whether fast-TF price enters a slow-TF structure zone
    (order block, FVG, liquidity pool). Until the slow candle closes, any
    violation is *temporary*. If price reclaims, it enters reclaim_pending.
    On slow candle close the outcome is confirmed or invalidated.
    """

    def __init__(self, redis_store: RuntimeRedisStore | None = None) -> None:
        # In-memory cache; Redis is the persistent backing store when available.
        self._states: dict[str, dict[str, Any]] = {}
        self._redis_store = redis_store

    async def evaluate(
        self,
        fast_tf_data: pd.DataFrame,
        slow_tf_data: pd.DataFrame,
        source_structure: dict,
        config: dict,
    ) -> dict:
        """Run a single evaluation cycle.

        Parameters
        ----------
        fast_tf_data : pd.DataFrame
            Recent candles for the fast timeframe (must have OHLCV columns).
        slow_tf_data : pd.DataFrame
            Recent candles for the slow timeframe.
        source_structure : dict
            The structure zone being guarded. Expected keys:
            - zone_type: str ("order_block", "fvg", "liquidity_pool")
            - direction: str ("bullish" or "bearish")
            - price_top: float
            - price_bottom: float
            - status: str
        config : dict
            Guard configuration. Expected keys:
            - guard_id: str
            - fast_timeframe: str
            - slow_timeframe: str
            - violation_policy: dict (optional, defaults to DEFAULT_VIOLATION_POLICY)
            - structure_type: str (optional)

        Returns
        -------
        dict with keys: guard_id, guard_state, action, reason_codes, violation
        """
        guard_id = config.get("guard_id", f"guard_{uuid.uuid4().hex[:8]}")
        fast_tf = config.get("fast_timeframe", "5m")
        slow_tf = config.get("slow_timeframe", "1h")
        violation_policy = {
            **DEFAULT_VIOLATION_POLICY,
            **config.get("violation_policy", {}),
        }

        # Validate timeframe hierarchy
        if get_rank(fast_tf) >= get_rank(slow_tf):
            return self._make_result(
                guard_id=guard_id,
                state=MTFGuardState.INACTIVE,
                action=MTFGuardAction.IGNORE,
                reason_codes=["fast_tf_not_lower_than_slow_tf"],
            )

        # Validate we have data
        if fast_tf_data.empty or slow_tf_data.empty:
            return self._make_result(
                guard_id=guard_id,
                state=MTFGuardState.INACTIVE,
                action=MTFGuardAction.IGNORE,
                reason_codes=["insufficient_data"],
            )

        # Extract zone boundaries
        zone_top = source_structure.get("price_top", 0.0)
        zone_bottom = source_structure.get("price_bottom", 0.0)
        zone_direction = source_structure.get("direction", "bullish")
        zone_status = source_structure.get("status", "active")

        if zone_top == 0 and zone_bottom == 0:
            return self._make_result(
                guard_id=guard_id,
                state=MTFGuardState.INACTIVE,
                action=MTFGuardAction.IGNORE,
                reason_codes=["no_zone_defined"],
            )

        if zone_status in ("invalidated", "expired", "mitigated"):
            return self._make_result(
                guard_id=guard_id,
                state=MTFGuardState.INACTIVE,
                action=MTFGuardAction.IGNORE,
                reason_codes=["zone_already_invalidated"],
            )

        # Get current prices from fast TF
        last_fast = fast_tf_data.iloc[-1]
        fast_close = float(last_fast["close"])
        fast_low = float(last_fast["low"])
        fast_high = float(last_fast["high"])

        # Get current slow TF candle state
        last_slow = slow_tf_data.iloc[-1]
        slow_close = float(last_slow["close"])

        # Determine if the slow candle has closed
        # Heuristic: if the slow TF dataframe has >= 2 rows and the last
        # row's timestamp differs from the previous by the expected interval,
        # the last candle is a new candle — meaning the previous one closed.
        htf_candle_closed = self._is_htf_candle_closed(slow_tf_data, slow_tf)

        # Retrieve previous state — try Redis first, fall back to in-memory
        prev = self._states.get(guard_id)
        if prev is None and self._redis_store is not None:
            try:
                redis_state = await self._redis_store.read_mtf_guard_pair(
                    config.get("strategy_id", ""),
                    config.get("symbol", ""),
                    fast_tf,
                    slow_tf,
                )
                if redis_state:
                    prev = redis_state
                    self._states[guard_id] = prev
            except Exception:
                logger.debug("Redis read failed for guard %s, using in-memory", guard_id)
        if prev is None:
            prev = {}
        prev_state = MTFGuardState(prev.get("guard_state", MTFGuardState.WATCHING.value))

        # ── State Machine ──
        violation_detected = self._check_violation(
            fast_close, fast_low, fast_high,
            zone_top, zone_bottom, zone_direction,
        )

        reclaim_detected = self._check_reclaim(
            fast_close, zone_top, zone_bottom, zone_direction,
        )

        new_state: MTFGuardState
        reason_codes: list[str] = []
        violation_info: dict = {}

        if prev_state in (MTFGuardState.INACTIVE, MTFGuardState.WATCHING):
            if violation_detected:
                if htf_candle_closed:
                    # Slow candle already closed with a violation => confirmed break
                    new_state = MTFGuardState.INVALIDATED
                    reason_codes.append("htf_close_confirmed_break")
                else:
                    new_state = MTFGuardState.TEMPORARY_VIOLATION
                    reason_codes.append("fast_tf_entered_htf_zone")
                violation_info = self._build_violation_info(
                    fast_close, fast_low, fast_high,
                    zone_top, zone_bottom, zone_direction,
                )
            else:
                new_state = MTFGuardState.WATCHING
                reason_codes.append("no_violation")

        elif prev_state == MTFGuardState.TEMPORARY_VIOLATION:
            if htf_candle_closed:
                # Slow candle closed — evaluate final state
                if violation_detected and not reclaim_detected:
                    new_state = MTFGuardState.INVALIDATED
                    reason_codes.append("htf_close_confirmed_break")
                else:
                    new_state = MTFGuardState.CONFIRMED
                    reason_codes.append("htf_close_reclaimed")
            elif reclaim_detected:
                new_state = MTFGuardState.RECLAIM_PENDING
                reason_codes.append("fast_tf_reclaimed_zone")
            else:
                new_state = MTFGuardState.TEMPORARY_VIOLATION
                reason_codes.append("violation_persists_awaiting_htf_close")
            violation_info = self._build_violation_info(
                fast_close, fast_low, fast_high,
                zone_top, zone_bottom, zone_direction,
            )

        elif prev_state == MTFGuardState.RECLAIM_PENDING:
            if htf_candle_closed:
                if reclaim_detected:
                    new_state = MTFGuardState.CONFIRMED
                    reason_codes.append("htf_close_confirmed_reclaim")
                else:
                    new_state = MTFGuardState.INVALIDATED
                    reason_codes.append("htf_close_reclaim_failed")
            elif violation_detected and not reclaim_detected:
                new_state = MTFGuardState.TEMPORARY_VIOLATION
                reason_codes.append("reclaim_failed_violation_resumed")
            else:
                new_state = MTFGuardState.RECLAIM_PENDING
                reason_codes.append("reclaim_pending_awaiting_htf_close")
            violation_info = self._build_violation_info(
                fast_close, fast_low, fast_high,
                zone_top, zone_bottom, zone_direction,
            )

        elif prev_state == MTFGuardState.PENDING_HTF_CLOSE:
            if htf_candle_closed:
                if violation_detected:
                    new_state = MTFGuardState.INVALIDATED
                    reason_codes.append("htf_close_confirmed_break")
                else:
                    new_state = MTFGuardState.CONFIRMED
                    reason_codes.append("htf_close_no_violation")
            else:
                new_state = MTFGuardState.PENDING_HTF_CLOSE
                reason_codes.append("awaiting_htf_close")

        elif prev_state == MTFGuardState.CONFIRMED:
            # Structure reclaimed — reset to watching
            new_state = MTFGuardState.WATCHING
            reason_codes.append("guard_reset_after_confirmation")

        elif prev_state == MTFGuardState.INVALIDATED:
            # Terminal state — stay invalidated
            new_state = MTFGuardState.INVALIDATED
            reason_codes.append("structure_invalidated")

        elif prev_state == MTFGuardState.EXPIRED:
            new_state = MTFGuardState.EXPIRED
            reason_codes.append("guard_expired")

        else:
            new_state = MTFGuardState.WATCHING
            reason_codes.append("unknown_state_reset")

        # Map state to action via violation policy
        action = self._state_to_action(new_state, violation_policy)

        # Persist state — in-memory and Redis
        state_data = {
            "guard_state": new_state.value,
            "action": action.value,
            "reason_codes": reason_codes,
            "violation": violation_info,
            "last_evaluated_at": datetime.now(timezone.utc).isoformat(),
        }
        self._states[guard_id] = state_data

        if self._redis_store is not None:
            try:
                await self._redis_store.write_mtf_guard_state(
                    strategy_id=config.get("strategy_id", ""),
                    symbol=config.get("symbol", ""),
                    fast_tf=fast_tf,
                    slow_tf=slow_tf,
                    state_data=state_data,
                    ttl=300,
                )
            except Exception:
                logger.warning("Redis write failed for guard %s — state is in-memory only", guard_id)

        return self._make_result(
            guard_id=guard_id,
            state=new_state,
            action=action,
            reason_codes=reason_codes,
            violation=violation_info,
        )

    # ── Helpers ──

    def _check_violation(
        self,
        close: float, low: float, high: float,
        zone_top: float, zone_bottom: float, direction: str,
    ) -> bool:
        """Check if fast-TF price has violated the HTF structure zone."""
        if direction == "bullish":
            # Bullish zone is support — violation if price goes below zone_bottom
            return low < zone_bottom
        else:
            # Bearish zone is resistance — violation if price goes above zone_top
            return high > zone_top

    def _check_reclaim(
        self,
        close: float,
        zone_top: float, zone_bottom: float, direction: str,
    ) -> bool:
        """Check if fast-TF close has reclaimed the zone."""
        if direction == "bullish":
            # Reclaim = close back above zone_bottom
            return close >= zone_bottom
        else:
            # Reclaim = close back below zone_top
            return close <= zone_top

    def _is_htf_candle_closed(self, slow_tf_data: pd.DataFrame, slow_tf: str) -> bool:
        """Heuristic to detect if the current slow candle has closed.

        If we have >= 2 rows, check if the time gap between the last two rows
        equals the expected slow TF interval — meaning a new candle has started
        (and the previous one closed).
        """
        if len(slow_tf_data) < 2:
            return False

        expected_minutes = get_minutes(slow_tf)
        last_time = slow_tf_data.index[-1] if isinstance(slow_tf_data.index, pd.DatetimeIndex) else None
        prev_time = slow_tf_data.index[-2] if isinstance(slow_tf_data.index, pd.DatetimeIndex) else None

        if last_time is not None and prev_time is not None:
            delta_minutes = (last_time - prev_time).total_seconds() / 60
            # The gap matches → the last candle is a new candle
            return abs(delta_minutes - expected_minutes) < expected_minutes * 0.1

        # Fallback: check using 'date' or 'timestamp' column
        for col in ("date", "timestamp", "time"):
            if col in slow_tf_data.columns:
                try:
                    last_t = pd.Timestamp(slow_tf_data[col].iloc[-1])
                    prev_t = pd.Timestamp(slow_tf_data[col].iloc[-2])
                    delta_min = (last_t - prev_t).total_seconds() / 60
                    return abs(delta_min - expected_minutes) < expected_minutes * 0.1
                except Exception:
                    pass

        return False

    def _state_to_action(
        self, state: MTFGuardState, policy: dict[str, str],
    ) -> MTFGuardAction:
        """Map guard state to an action based on the violation policy."""
        mapping: dict[MTFGuardState, str] = {
            MTFGuardState.INACTIVE: "allow",
            MTFGuardState.WATCHING: "allow",
            MTFGuardState.PENDING_HTF_CLOSE: "observe",
            MTFGuardState.TEMPORARY_VIOLATION: policy.get("temporary_violation", "block_entry"),
            MTFGuardState.RECLAIM_PENDING: policy.get("reclaim_pending", "require_confirmation"),
            MTFGuardState.CONFIRMED: policy.get("confirmed_reclaim", "allow"),
            MTFGuardState.INVALIDATED: policy.get("confirmed_break", "invalidate"),
            MTFGuardState.EXPIRED: "ignore",
        }
        action_str = mapping.get(state, "ignore")

        # Normalize to MTFGuardAction values
        action_map = {
            "allow": MTFGuardAction.ALLOW,
            "observe": MTFGuardAction.OBSERVE,
            "require_confirmation": MTFGuardAction.REQUIRE_CONFIRM,
            "require_confirm": MTFGuardAction.REQUIRE_CONFIRM,
            "block_entry": MTFGuardAction.BLOCK_ENTRY,
            "reduce_size": MTFGuardAction.REDUCE_SIZE,
            "invalidate": MTFGuardAction.BLOCK_ENTRY,  # invalidated => block
            "ignore": MTFGuardAction.IGNORE,
        }
        return action_map.get(action_str, MTFGuardAction.IGNORE)

    def _build_violation_info(
        self,
        close: float, low: float, high: float,
        zone_top: float, zone_bottom: float, direction: str,
    ) -> dict:
        if direction == "bullish":
            penetration = max(0.0, zone_bottom - low)
            zone_size = zone_top - zone_bottom if zone_top > zone_bottom else 1.0
            penetration_ratio = min(1.0, penetration / zone_size) if zone_size > 0 else 0.0
        else:
            penetration = max(0.0, high - zone_top)
            zone_size = zone_top - zone_bottom if zone_top > zone_bottom else 1.0
            penetration_ratio = min(1.0, penetration / zone_size) if zone_size > 0 else 0.0

        return {
            "fast_close": close,
            "fast_low": low,
            "fast_high": high,
            "zone_top": zone_top,
            "zone_bottom": zone_bottom,
            "zone_direction": direction,
            "penetration": penetration,
            "penetration_ratio": penetration_ratio,
        }

    @staticmethod
    def _make_result(
        guard_id: str,
        state: MTFGuardState,
        action: MTFGuardAction,
        reason_codes: list[str] | None = None,
        violation: dict | None = None,
    ) -> dict:
        return {
            "guard_id": guard_id,
            "guard_state": state.value,
            "action": action.value,
            "reason_codes": reason_codes or [],
            "violation": violation or {},
        }

    def reset(self, guard_id: str) -> None:
        """Reset a guard to WATCHING state."""
        self._states.pop(guard_id, None)

    async def get_state(self, guard_id: str, config: dict | None = None) -> dict | None:
        """Get current state for a guard — checks in-memory cache then Redis."""
        state = self._states.get(guard_id)
        if state is not None:
            return state
        if self._redis_store is not None and config is not None:
            try:
                redis_state = await self._redis_store.read_mtf_guard_pair(
                    config.get("strategy_id", ""),
                    config.get("symbol", ""),
                    config.get("fast_timeframe", ""),
                    config.get("slow_timeframe", ""),
                )
                if redis_state:
                    self._states[guard_id] = redis_state
                    return redis_state
            except Exception:
                logger.debug("Redis read failed for guard %s", guard_id)
        return None
