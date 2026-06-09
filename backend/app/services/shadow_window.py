"""Shadow Window Service — tracks the observation window until slow candle close.

A "shadow window" is the period between a fast-timeframe structure event
and the next slow-timeframe candle close. During this window, fast-TF
price movements are tracked for zone violations, reclaims, and fill
progression.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from app.services.structure.timeframe import get_minutes

logger = logging.getLogger(__name__)


class ShadowWindowState(str, Enum):
    """Shadow window lifecycle states."""
    ACTIVE = "active"
    VIOLATION = "violation"
    RECLAIM = "reclaim"
    EXPIRED = "expired"
    CLOSED = "closed"  # slow candle closed


@dataclass
class ShadowWindowSnapshot:
    """Current state of a shadow window."""
    window_id: str
    symbol: str
    fast_timeframe: str
    slow_timeframe: str
    zone_type: str
    direction: str = "bullish"  # "bullish" (support) or "bearish" (resistance)
    state: ShadowWindowState = ShadowWindowState.ACTIVE
    fast_candle_count: int = 0
    max_fast_candles: int = 12
    low_tf_touched: bool = False
    filled_ratio: float = 0.0
    zone_top: float = 0.0
    zone_bottom: float = 0.0
    lowest_price: float = 0.0
    highest_price: float = 0.0
    violation_count: int = 0
    reclaim_count: int = 0
    started_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    reason_codes: list[str] = field(default_factory=list)


class ShadowWindowService:
    """Manages shadow observation windows for multi-TF guard.

    Each window tracks fast-TF candle progression within a slow-TF candle
    period, monitoring for zone violations and reclaims.
    """

    def __init__(self) -> None:
        self._windows: dict[str, ShadowWindowSnapshot] = {}

    def open_window(
        self,
        window_id: str,
        symbol: str,
        fast_timeframe: str,
        slow_timeframe: str,
        zone_type: str,
        zone_top: float,
        zone_bottom: float,
        direction: str = "bullish",
        max_fast_candles: int = 12,
    ) -> ShadowWindowSnapshot:
        """Open a new shadow window."""
        now = datetime.now(timezone.utc)
        window = ShadowWindowSnapshot(
            window_id=window_id,
            symbol=symbol,
            fast_timeframe=fast_timeframe,
            slow_timeframe=slow_timeframe,
            zone_type=zone_type,
            direction=direction,
            zone_top=zone_top,
            zone_bottom=zone_bottom,
            max_fast_candles=max_fast_candles,
            started_at=now,
            updated_at=now,
        )
        self._windows[window_id] = window
        logger.debug("shadow window opened: %s for %s %s→%s",
                      window_id, symbol, fast_timeframe, slow_timeframe)
        return window

    def update(
        self,
        window_id: str,
        fast_tf_candle: dict,
        slow_tf_state: dict,
    ) -> ShadowWindowSnapshot:
        """Update a shadow window with a new fast-TF candle.

        Parameters
        ----------
        window_id : str
            The window to update.
        fast_tf_candle : dict
            Must contain: close, low, high.
        slow_tf_state : dict
            Must contain: candle_closed (bool).

        Returns
        -------
        Updated ShadowWindowSnapshot.
        """
        window = self._windows.get(window_id)
        if window is None:
            raise ValueError(f"Shadow window '{window_id}' not found")

        if window.state in (ShadowWindowState.EXPIRED, ShadowWindowState.CLOSED):
            return window

        now = datetime.now(timezone.utc)
        window.updated_at = now
        window.fast_candle_count += 1

        close = float(fast_tf_candle.get("close", 0))
        low = float(fast_tf_candle.get("low", 0))
        high = float(fast_tf_candle.get("high", 0))

        # Track extremes
        if window.lowest_price == 0 or low < window.lowest_price:
            window.lowest_price = low
        if window.highest_price == 0 or high > window.highest_price:
            window.highest_price = high

        # Check zone touch and violation
        zone_touched = self._check_zone_touch(low, high, window.zone_top, window.zone_bottom)
        if zone_touched:
            window.low_tf_touched = True

        # Update filled ratio
        window.filled_ratio = self._calc_filled_ratio(
            window.lowest_price, window.highest_price,
            window.zone_top, window.zone_bottom,
        )

        # Check violation (price closes beyond zone)
        violated = self._check_violation(close, low, high, window.zone_top, window.zone_bottom, window.direction)
        if violated:
            window.violation_count += 1
            window.state = ShadowWindowState.VIOLATION
            if "zone_violated" not in window.reason_codes:
                window.reason_codes.append("zone_violated")
        elif window.state == ShadowWindowState.VIOLATION:
            # Price reclaimed after violation
            reclaimed = self._check_reclaim(close, window.zone_top, window.zone_bottom)
            if reclaimed:
                window.reclaim_count += 1
                window.state = ShadowWindowState.RECLAIM
                if "zone_reclaimed" not in window.reason_codes:
                    window.reason_codes.append("zone_reclaimed")

        # Check slow candle closed
        candle_closed = slow_tf_state.get("candle_closed", False)
        if candle_closed:
            if window.state == ShadowWindowState.VIOLATION:
                # HTF close confirms the violation is real — keep VIOLATION state
                window.reason_codes.append("slow_candle_closed_with_violation")
            else:
                window.state = ShadowWindowState.CLOSED
                window.reason_codes.append("slow_candle_closed")

        # Check expiry
        if window.fast_candle_count >= window.max_fast_candles and not candle_closed:
            window.state = ShadowWindowState.EXPIRED
            window.reason_codes.append("max_fast_candles_reached")

        return window

    def is_expired(self, window_id: str) -> bool:
        """Check if a shadow window has expired."""
        window = self._windows.get(window_id)
        if window is None:
            return True
        return window.state in (ShadowWindowState.EXPIRED, ShadowWindowState.CLOSED)

    def get_window(self, window_id: str) -> ShadowWindowSnapshot | None:
        """Get a specific window snapshot."""
        return self._windows.get(window_id)

    def get_active_windows(self, symbol: str | None = None) -> list[ShadowWindowSnapshot]:
        """Get all active (non-expired, non-closed) windows."""
        result = []
        for w in self._windows.values():
            if w.state in (ShadowWindowState.EXPIRED, ShadowWindowState.CLOSED):
                continue
            if symbol is not None and w.symbol != symbol:
                continue
            result.append(w)
        return result

    def get_all_windows(self, symbol: str | None = None) -> list[ShadowWindowSnapshot]:
        """Get all windows, including expired/closed."""
        if symbol is None:
            return list(self._windows.values())
        return [w for w in self._windows.values() if w.symbol == symbol]

    def close_window(self, window_id: str) -> None:
        """Close and remove a window."""
        self._windows.pop(window_id, None)

    def cleanup_expired(self) -> int:
        """Remove expired/closed windows. Returns count removed."""
        to_remove = [
            wid for wid, w in self._windows.items()
            if w.state in (ShadowWindowState.EXPIRED, ShadowWindowState.CLOSED)
        ]
        for wid in to_remove:
            del self._windows[wid]
        return len(to_remove)

    # ── Internal helpers ──

    @staticmethod
    def _check_zone_touch(low: float, high: float, zone_top: float, zone_bottom: float) -> bool:
        """Price touched the zone (wick entered zone range)."""
        return low <= zone_top and high >= zone_bottom

    @staticmethod
    def _check_violation(
        close: float, low: float, high: float,
        zone_top: float, zone_bottom: float,
        direction: str = "bullish",
    ) -> bool:
        """Price violated the zone (closed beyond zone boundary).

        For bullish (support) zones: violation = price closed below zone_bottom.
        For bearish (resistance) zones: violation = price closed above zone_top.
        """
        if direction == "bearish":
            return close > zone_top
        # bullish / default: support zone broken when price drops below
        return close < zone_bottom

    @staticmethod
    def _check_reclaim(close: float, zone_top: float, zone_bottom: float) -> bool:
        """Price reclaimed the zone (close back within zone)."""
        return zone_bottom <= close <= zone_top

    @staticmethod
    def _calc_filled_ratio(
        lowest: float, highest: float,
        zone_top: float, zone_bottom: float,
    ) -> float:
        """Calculate how much of the zone has been filled by price action."""
        zone_size = zone_top - zone_bottom
        if zone_size <= 0:
            return 0.0

        # The filled portion is the overlap of [lowest, highest] with [zone_bottom, zone_top]
        overlap_bottom = max(lowest, zone_bottom)
        overlap_top = min(highest, zone_top)
        if overlap_top <= overlap_bottom:
            return 0.0

        return min(1.0, (overlap_top - overlap_bottom) / zone_size)
