from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timezone, timedelta

import pandas as pd

from app.domain.snapshot import (
    RuntimeDecisionSnapshot, CandidateSignal, IndicatorContext,
    AIContext, RiskContext, ExecutionPlan, StructureContext,
    LiquidityExecutionContext,
)
from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.structure.engine import StructureEngine
from app.services.structure.models import StructureDirection, SweepState, StructureStatus
from app.services.structure.stop_calculator import calculate_structure_stop
from app.services.structure.execution_safety import check_execution_safety

logger = logging.getLogger(__name__)

TIMEFRAME_SECONDS = {
    "1m": 60, "3m": 180, "5m": 300, "15m": 900, "30m": 1800,
    "1h": 3600, "2h": 7200, "4h": 14400, "1d": 86400,
}


class DecisionEngine:
    def __init__(self, redis_store: RuntimeRedisStore, risk_firewall: AccountRiskFirewall):
        self._store = redis_store
        self._firewall = risk_firewall
        self._structure_engines: dict[str, StructureEngine] = {}

    def _get_structure_engine(self, symbol: str, timeframe: str) -> StructureEngine:
        key = f"{symbol}:{timeframe}"
        if key not in self._structure_engines:
            self._structure_engines[key] = StructureEngine(timeframe=timeframe)
        return self._structure_engines[key]

    async def evaluate(
        self,
        strategy_id: str,
        dsl: dict,
        dataframe,
        account_id: str,
        exchange: str,
        symbol: str,
        timeframe: str,
    ) -> RuntimeDecisionSnapshot | None:
        t0 = time.monotonic()

        entry_fired, reason_codes = self._evaluate_entry(dsl, dataframe)
        if not entry_fired:
            return None

        candidate = CandidateSignal(
            direction="long",
            intent="open_position",
            confidence=0.5,
            reason_codes=reason_codes,
        )

        # Structure analysis
        struct_engine = self._get_structure_engine(symbol, timeframe)
        struct_snapshot = struct_engine.analyze(dataframe)

        structure_ctx = StructureContext(
            market_regime=struct_snapshot.market_regime.value,
            structure_score=struct_snapshot.structure_score,
            sweep=self._sweep_to_dict(struct_snapshot.active_sweeps),
            fvg=self._fvg_to_dict(struct_snapshot.fvg_zones),
            order_block=self._ob_to_dict(struct_snapshot.order_blocks),
        )

        indicator_ctx = self._build_indicator_context(dsl, dataframe)
        ai_ctx = await self._read_ai_cache(symbol)
        risk_state = await self._firewall.check(account_id)

        if not risk_state.allowed:
            exec_plan = ExecutionPlan(
                decision="reject_trade",
                reject_reason=risk_state.reason_code,
            )
            all_reasons = reason_codes + [risk_state.reason_code]
        else:
            last_close = float(dataframe["close"].iloc[-1])
            risk_cfg = dsl.get("risk", {})
            stop_policy = dsl.get("stop_policy", {})

            # Use structure stop if available
            if struct_snapshot.active_sweeps or struct_snapshot.fvg_zones or struct_snapshot.order_blocks:
                atr_val = float(self._compute_last_atr(dataframe))
                stop_result = calculate_structure_stop(
                    direction=struct_snapshot.structure_direction or StructureDirection.BULLISH,
                    entry_price=last_close,
                    sweeps=struct_snapshot.active_sweeps,
                    fvgs=struct_snapshot.fvg_zones,
                    order_blocks=struct_snapshot.order_blocks,
                    atr=atr_val,
                    atr_buffer_coef=stop_policy.get("atr_buffer_coef", 0.3),
                    fallback_stop_pct=stop_policy.get("fallback_stop_pct", 0.02),
                    max_stop_distance_pct=stop_policy.get("max_stop_distance_pct", 0.03),
                )
                stop_price = stop_result.stop_price
            else:
                stoploss_pct = stop_policy.get("fallback_stop_pct", abs(risk_cfg.get("stoploss", -0.05)))
                stop_price = last_close * (1 - stoploss_pct)

            pos_cfg = dsl.get("position_policy", {})
            pos_pct = pos_cfg.get("max_position_pct",
                                  dsl.get("position_sizing", {}).get("position_pct", 0.1))

            exec_plan = ExecutionPlan(
                decision="allow_trade",
                entry_type="limit",
                entry_price=last_close,
                stop_price=stop_price,
                position_size=pos_pct,
            )
            all_reasons = reason_codes + ["account_risk_allowed"]

        latency_ms = int((time.monotonic() - t0) * 1000)
        ttl = TIMEFRAME_SECONDS.get(timeframe, 300)

        snapshot = RuntimeDecisionSnapshot(
            snapshot_id=f"snap_{uuid.uuid4().hex[:16]}",
            strategy_id=strategy_id,
            exchange=exchange,
            symbol=symbol,
            timeframe=timeframe,
            valid_until=datetime.now(timezone.utc) + timedelta(seconds=ttl),
            candidate_signal=candidate,
            indicator_context=indicator_ctx,
            structure_context=structure_ctx,
            ai_context=ai_ctx,
            risk_context=RiskContext(
                account_risk_state="allowed" if risk_state.allowed else "blocked",
                risk_per_trade=0.01,
                daily_loss_remaining=max(0, 0.03 - abs(risk_state.daily_pnl)),
                weekly_loss_remaining=max(0, 0.08 - abs(risk_state.weekly_pnl)),
            ),
            execution_plan=exec_plan,
            reason_codes=all_reasons,
            latency_ms=latency_ms,
        )

        await self._store.write_snapshot(
            strategy_id, symbol, timeframe,
            snapshot.model_dump(mode="json"), ttl=ttl,
        )

        return snapshot

    def _evaluate_entry(self, dsl: dict, dataframe) -> tuple[bool, list[str]]:
        try:
            from app.services.dsl_interpreter import (
                compute_all_indicators, evaluate_group, evaluate_filters,
            )
            cache = compute_all_indicators(dataframe, dsl)

            entry_key = "entry_logic" if "entry_logic" in dsl else "entry"
            entry_group = dsl.get(entry_key, {})
            filters = dsl.get("filters", [])

            entry_signal = evaluate_group(dataframe, entry_group, cache)
            filter_signal = evaluate_filters(dataframe, filters, cache)
            combined = entry_signal & filter_signal

            if combined.iloc[-1]:
                reasons = []
                for rule in entry_group.get("rules", []):
                    indicator = rule.get("indicator", rule.get("type", "unknown"))
                    reasons.append(f"{indicator}_triggered")
                return True, reasons

            return False, []
        except Exception:
            logger.exception("entry evaluation failed")
            return False, []

    def _build_indicator_context(self, dsl: dict, dataframe) -> IndicatorContext:
        try:
            from app.services.dsl_interpreter import compute_all_indicators
            cache = compute_all_indicators(dataframe, dsl)
            values = {}
            for key, series in cache.items():
                if len(series) > 0:
                    val = series.iloc[-1]
                    if val is not None and val == val:
                        values[key] = float(val)
            return IndicatorContext(values=values)
        except Exception:
            return IndicatorContext()

    async def _read_ai_cache(self, symbol: str) -> AIContext:
        cache = await self._store.read_ai_cache(symbol)
        if not cache:
            return AIContext(cache_state="missing")
        return AIContext(
            cache_state="fresh",
            ai_risk_score=cache.get("ai_risk_score", 0.0),
            risk_flags=cache.get("risk_flags", []),
        )

    def _sweep_to_dict(self, sweeps):
        confirmed = [s for s in sweeps if s.state == SweepState.CONFIRMED_SWEEP]
        if not confirmed:
            return None
        s = confirmed[-1]
        return {
            "state": s.state.value,
            "type": s.sweep_type,
            "swept_level": s.swept_level,
            "sweep_low": s.sweep_low,
            "reclaim_price": s.reclaim_price,
            "confidence": s.confidence,
        }

    def _fvg_to_dict(self, fvgs):
        active = [f for f in fvgs if f.status == StructureStatus.ACTIVE]
        if not active:
            return None
        f = active[-1]
        return {
            "status": f.status.value,
            "direction": f.direction.value,
            "top": f.price_top,
            "bottom": f.price_bottom,
            "filled_ratio": f.filled_ratio,
        }

    def _ob_to_dict(self, obs):
        active = [o for o in obs if o.status == StructureStatus.ACTIVE]
        if not active:
            return None
        o = active[-1]
        return {
            "status": o.status.value,
            "direction": o.direction.value,
            "top": o.price_top,
            "bottom": o.price_bottom,
        }

    def _compute_last_atr(self, df, period=14):
        tr = pd.concat([
            df["high"] - df["low"],
            abs(df["high"] - df["close"].shift(1)),
            abs(df["low"] - df["close"].shift(1)),
        ], axis=1).max(axis=1)
        atr = tr.rolling(period).mean()
        val = atr.iloc[-1]
        return val if not pd.isna(val) else 0.0
