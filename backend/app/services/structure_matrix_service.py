"""Structure Matrix Service — 多周期结构矩阵"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.services.runtime_redis_store import RuntimeRedisStore

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

    async def get_matrix(self, symbol: str) -> MatrixResult:
        if self._store:
            cached = await self._store.read_structure_matrix(symbol)
            if cached:
                return self._deserialize(cached)

        result = self._build_mock_matrix(symbol)

        if self._store:
            await self._store.write_structure_matrix(symbol, self._serialize(result), ttl=5)

        return result

    def _build_mock_matrix(self, symbol: str) -> MatrixResult:
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
