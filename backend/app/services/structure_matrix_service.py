"""Structure Matrix Service — multi-timeframe structure analysis.

Runs StructureEngine.analyze() across multiple timeframes (5m, 15m, 1h, 4h)
and composes a unified matrix showing zone health per TF. Falls back to
mock data when no market data is available.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Optional

import pandas as pd

from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.structure.engine import StructureEngine
from app.services.structure.models import (
    StructureSnapshot, StructureStatus, StructureDirection,
)

logger = logging.getLogger(__name__)


@dataclass
class MatrixCell:
    zone_type: str
    status: str = "unknown"
    current_strength: float = 0
    filled_ratio: float = 0
    temporary_violation: bool = False
    action: str = ""
    reason_codes: list[str] = field(default_factory=list)


@dataclass
class MatrixRow:
    timeframe: str
    cells: dict[str, MatrixCell] = field(default_factory=dict)


@dataclass
class MatrixResult:
    symbol: str = ""
    base_timeframe: str = "5m"
    state: str = "healthy"
    reason_codes: list[str] = field(default_factory=list)
    rows: list[MatrixRow] = field(default_factory=list)


class StructureMatrixService:
    TIMEFRAMES = ["5m", "15m", "1h", "4h"]
    ZONE_TYPES = ["bullish_ob", "fvg", "liquidity_pool"]

    def __init__(self, redis_store: RuntimeRedisStore | None = None):
        self._store = redis_store
        self._engines: dict[str, StructureEngine] = {}

    def _get_engine(self, timeframe: str) -> StructureEngine:
        if timeframe not in self._engines:
            self._engines[timeframe] = StructureEngine(timeframe=timeframe)
        return self._engines[timeframe]

    async def get_matrix(self, symbol: str) -> MatrixResult:
        """Build the structure matrix for a symbol.

        Tries Redis cache first, then attempts real analysis by fetching
        market data from the store, and falls back to mock data if neither
        is available.
        """
        # Try cache first
        if self._store:
            cached = await self._store.read_structure_matrix(symbol)
            if cached:
                return self._deserialize(cached)

        # Try to build real matrix from stored market data
        market_data = await self._fetch_market_data(symbol)
        if market_data:
            result = self._build_real_matrix(symbol, market_data)
        else:
            logger.warning(
                "No market data available for %s — falling back to mock matrix",
                symbol,
            )
            result = self._build_mock_matrix(symbol)

        # Cache result
        if self._store:
            await self._store.write_structure_matrix(symbol, self._serialize(result), ttl=5)

        return result

    async def _fetch_market_data(
        self, symbol: str,
    ) -> dict[str, pd.DataFrame] | None:
        """Attempt to fetch OHLCV data for all timeframes.

        Returns a dict mapping timeframe to DataFrame, or None when no
        market-data source is available. Override or extend this method
        to integrate with a live data feed or exchange client.
        """
        # TODO: wire up a market data provider (exchange client, DB, etc.)
        return None

    def _build_real_matrix(
        self,
        symbol: str,
        market_data: dict[str, pd.DataFrame],
    ) -> MatrixResult:
        """Analyze structure across all timeframes using StructureEngine."""
        rows: list[MatrixRow] = []
        overall_state = "healthy"
        overall_reasons: list[str] = []

        for tf in self.TIMEFRAMES:
            df = market_data.get(tf)
            if df is None or df.empty:
                # Skip timeframes with no data
                rows.append(MatrixRow(timeframe=tf, cells={}))
                continue

            engine = self._get_engine(tf)
            try:
                snapshot = engine.analyze(df)
            except Exception:
                logger.exception("structure analysis failed for %s %s", symbol, tf)
                rows.append(MatrixRow(timeframe=tf, cells={}))
                continue

            cells = self._snapshot_to_cells(snapshot, tf)
            rows.append(MatrixRow(timeframe=tf, cells=cells))

            # Check for violations
            for zone_key, cell in cells.items():
                if cell.temporary_violation:
                    overall_state = "warning"
                    reason = f"{tf}_{zone_key}_violation"
                    overall_reasons.append(reason)
                elif cell.status == "warning":
                    if overall_state == "healthy":
                        overall_state = "warning"
                    overall_reasons.append(f"{tf}_{zone_key}_weakening")

        return MatrixResult(
            symbol=symbol,
            state=overall_state,
            reason_codes=overall_reasons,
            rows=rows,
        )

    def _snapshot_to_cells(
        self,
        snapshot: StructureSnapshot,
        timeframe: str,
    ) -> dict[str, MatrixCell]:
        """Convert a StructureSnapshot into matrix cells."""
        cells: dict[str, MatrixCell] = {}

        # Order blocks
        active_obs = [
            ob for ob in snapshot.order_blocks
            if ob.status not in (StructureStatus.INVALIDATED, StructureStatus.EXPIRED)
        ]
        if active_obs:
            best_ob = max(active_obs, key=lambda ob: ob.current_strength)
            ob_status = "active" if best_ob.current_strength >= 0.5 else "warning"
            ob_violation = best_ob.status == StructureStatus.TOUCHED and best_ob.touched_count >= 2
            ob_action = "allow"
            ob_reasons: list[str] = []
            if ob_violation:
                ob_action = "reduce_size"
                ob_reasons.append(f"ob_multi_touched_{timeframe}")
            elif ob_status == "warning":
                ob_action = "observe"
                ob_reasons.append(f"ob_weakening_{timeframe}")

            cells["bullish_ob"] = MatrixCell(
                zone_type="order_block",
                status=ob_status,
                current_strength=round(best_ob.current_strength, 3),
                temporary_violation=ob_violation,
                action=ob_action,
                reason_codes=ob_reasons,
            )
        else:
            cells["bullish_ob"] = MatrixCell(
                zone_type="order_block", status="inactive", action="allow",
            )

        # FVGs
        active_fvgs = [
            f for f in snapshot.fvg_zones
            if f.status not in (StructureStatus.INVALIDATED, StructureStatus.EXPIRED)
        ]
        if active_fvgs:
            best_fvg = max(active_fvgs, key=lambda f: f.current_strength)
            fvg_status = "active" if best_fvg.current_strength >= 0.5 else "warning"
            fvg_violation = best_fvg.filled_ratio >= 0.8
            fvg_action = "allow"
            fvg_reasons: list[str] = []
            if fvg_violation:
                fvg_action = "reduce_size"
                fvg_reasons.append(f"fvg_nearly_filled_{timeframe}")
            elif fvg_status == "warning":
                fvg_action = "observe"
                fvg_reasons.append(f"fvg_weakening_{timeframe}")

            cells["fvg"] = MatrixCell(
                zone_type="fvg",
                status=fvg_status,
                current_strength=round(best_fvg.current_strength, 3),
                filled_ratio=round(best_fvg.filled_ratio, 3),
                temporary_violation=fvg_violation,
                action=fvg_action,
                reason_codes=fvg_reasons,
            )
        else:
            cells["fvg"] = MatrixCell(
                zone_type="fvg", status="inactive", action="allow",
            )

        # Liquidity pools
        from app.services.structure.models import PoolStatus
        active_pools = [
            p for p in snapshot.liquidity_pools
            if p.status in (PoolStatus.ACTIVE, PoolStatus.TOUCHED)
        ]
        if active_pools:
            best_pool = max(active_pools, key=lambda p: p.current_strength)
            pool_status = "active" if best_pool.current_strength >= 0.5 else "warning"
            pool_violation = best_pool.status == PoolStatus.TOUCHED
            pool_action = "allow"
            pool_reasons: list[str] = []
            if pool_violation:
                pool_action = "observe"
                pool_reasons.append(f"pool_touched_{timeframe}")
            elif pool_status == "warning":
                pool_action = "observe"
                pool_reasons.append(f"pool_weakening_{timeframe}")

            cells["liquidity_pool"] = MatrixCell(
                zone_type="liquidity_pool",
                status=pool_status,
                current_strength=round(best_pool.current_strength, 3),
                temporary_violation=pool_violation,
                action=pool_action,
                reason_codes=pool_reasons,
            )
        else:
            cells["liquidity_pool"] = MatrixCell(
                zone_type="liquidity_pool", status="inactive", action="allow",
            )

        return cells

    def _build_mock_matrix(self, symbol: str) -> MatrixResult:
        """Fallback mock data when no market data is available."""
        rows = []
        overall_state = "healthy"
        overall_reasons: list[str] = []

        mock_data = {
            "5m": {"bullish_ob": (0.78, "active"), "fvg": (0.65, "active"), "liquidity_pool": (0.70, "active")},
            "15m": {"bullish_ob": (0.82, "active"), "fvg": (0.71, "active"), "liquidity_pool": (0.60, "active")},
            "1h": {"bullish_ob": (0.41, "warning"), "fvg": (0.55, "active"), "liquidity_pool": (0.35, "warning")},
            "4h": {"bullish_ob": (0.88, "active"), "fvg": (0.92, "active"), "liquidity_pool": (0.85, "active")},
        }

        for tf in self.TIMEFRAMES:
            cells = {}
            tf_data = mock_data.get(tf, {})
            for zt in self.ZONE_TYPES:
                strength, status = tf_data.get(zt, (0.5, "unknown"))
                violation = status == "warning"
                action = "reduce_size" if violation else "allow"
                reasons = []
                if violation:
                    reasons.append(f"{tf}_{zt}_violation")
                    overall_state = "warning"
                    overall_reasons.append(f"{tf}_{zt}_violation")
                cells[zt] = MatrixCell(
                    zone_type=zt, status=status, current_strength=strength,
                    temporary_violation=violation, action=action, reason_codes=reasons,
                )
            rows.append(MatrixRow(timeframe=tf, cells=cells))

        return MatrixResult(symbol=symbol, state=overall_state, reason_codes=overall_reasons, rows=rows)

    def _serialize(self, result: MatrixResult) -> dict:
        return {
            "symbol": result.symbol,
            "base_timeframe": result.base_timeframe,
            "state": result.state,
            "reason_codes": result.reason_codes,
            "rows": [
                {
                    "timeframe": row.timeframe,
                    "cells": {k: {
                        "zone_type": c.zone_type, "status": c.status,
                        "current_strength": c.current_strength, "filled_ratio": c.filled_ratio,
                        "temporary_violation": c.temporary_violation, "action": c.action,
                        "reason_codes": c.reason_codes,
                    } for k, c in row.cells.items()},
                } for row in result.rows
            ],
        }

    def _deserialize(self, data: dict) -> MatrixResult:
        rows = []
        for row_data in data.get("rows", []):
            cells = {}
            for k, c in row_data.get("cells", {}).items():
                cells[k] = MatrixCell(**c)
            rows.append(MatrixRow(timeframe=row_data["timeframe"], cells=cells))
        return MatrixResult(
            symbol=data["symbol"], base_timeframe=data.get("base_timeframe", "5m"),
            state=data["state"], reason_codes=data.get("reason_codes", []), rows=rows,
        )
