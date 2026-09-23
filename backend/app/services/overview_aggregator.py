"""OverviewAggregatorService — parallel dashboard aggregation with safe fallbacks."""
from __future__ import annotations

import asyncio
import logging
from typing import Any

logger = logging.getLogger(__name__)


def _provider_category_state(category: str) -> str:
    """Derive a health state for a provider category from persisted health rows.

    Returns ok / degraded / error / unknown / unconfigured based on the
    provider_configs status field maintained by ProviderHealthScheduler.
    """
    try:
        from sqlalchemy import select

        from app.database import SessionLocal
        from app.models.provider_config import ProviderConfig

        db = SessionLocal()
        try:
            rows = list(db.scalars(
                select(ProviderConfig).where(
                    ProviderConfig.category == category,
                    ProviderConfig.enabled.is_(True),
                )
            ).all())
        finally:
            db.close()

        if not rows:
            return "unconfigured"
        statuses = [r.status for r in rows]
        if any(s == "active" for s in statuses):
            return "ok"
        if any(s in ("rate_limited", "unknown") for s in statuses):
            return "degraded"
        return "error"
    except Exception:
        logger.exception("provider category state lookup failed for %s", category)
        return "unknown"


class OverviewAggregatorService:
    """Aggregates data from multiple sub-services into a single dashboard response.

    Each sub-fetcher is isolated: if one fails, the others still return data.
    The aggregator derives top-level ``state``, ``reason_codes``, and
    ``available_actions`` from the collected data.
    """

    async def aggregate(self) -> dict:
        results = await asyncio.gather(
            self._fetch_account(),
            self._fetch_runtime(),
            self._fetch_risk(),
            self._fetch_system(),
            return_exceptions=True,
        )

        account = self._safe_result(results[0], self._default_account())
        runtime = self._safe_result(results[1], self._default_runtime())
        risk = self._safe_result(results[2], self._default_risk())
        system = self._safe_result(results[3], self._default_system())

        state, reason_codes = self._derive_state(risk, system)
        available_actions = self._derive_actions(state)

        recent_decisions = await self._fetch_recent_decisions()
        alerts = await self._fetch_alerts()

        return {
            "state": state,
            "reason_codes": reason_codes,
            "available_actions": available_actions,
            "account": account,
            "runtime": runtime,
            "risk": risk,
            "system": system,
            "recent_decisions": recent_decisions,
            "alerts": alerts,
        }

    # ── Sub-fetchers ──────────────────────────────────────────────────

    async def _fetch_account(self) -> dict:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        balance = await ft.get_balance()
        if not FreqtradeClient.is_success(balance):
            logger.warning("FreqtradeClient.get_balance failed: %s", balance.get("error"))
            return self._default_account()

        # Map freqtrade balance payload to our schema
        total = float(balance.get("total", 0))
        currencies = balance.get("currencies", [])
        # Freqtrade returns stake currency info
        currency = balance.get("stake", balance.get("symbol", "USDT"))

        return {
            "equity": total,
            "currency": currency if isinstance(currency, str) else "USDT",
            "today_pnl_pct": 0.0,
            "week_pnl_pct": 0.0,
            "max_drawdown_pct": 0.0,
            "sharpe_ratio": 0.0,
        }

    async def _fetch_runtime(self) -> dict:
        from app.database import SessionLocal
        from app.domain.execution import StrategyRun, FreqtradeRun
        from app.domain.order import ExecutionOrder
        from sqlalchemy import select, func

        db = SessionLocal()
        try:
            running_strategies = db.scalar(
                select(func.count()).select_from(StrategyRun).where(
                    StrategyRun.status == "running"
                )
            ) or 0

            open_positions = db.scalar(
                select(func.count()).select_from(ExecutionOrder).where(
                    ExecutionOrder.status.in_(["open", "partially_filled"])
                )
            ) or 0

            pending_orders = db.scalar(
                select(func.count()).select_from(ExecutionOrder).where(
                    ExecutionOrder.status == "pending"
                )
            ) or 0

            reconciling_count = db.scalar(
                select(func.count()).select_from(FreqtradeRun).where(
                    FreqtradeRun.status == "reconciliating"
                )
            ) or 0

            return {
                "running_strategies": running_strategies,
                "open_positions": open_positions,
                "pending_orders": pending_orders,
                "reconciling_count": reconciling_count,
            }
        except Exception:
            logger.exception("Failed to fetch runtime from DB")
            return self._default_runtime()
        finally:
            db.close()

    async def _fetch_risk(self) -> dict:
        from app.config import settings
        from app.services.runtime_redis_store import RuntimeRedisStore

        store = RuntimeRedisStore(redis_url=settings.redis_url)
        risk_data: dict[str, Any] = {}
        try:
            raw = await store._get("pd:runtime:global_risk_state")
            if raw and isinstance(raw, dict):
                risk_data = raw
        except Exception:
            pass

        return {
            "global_state": risk_data.get("global_state", "normal"),
            "daily_loss_remaining_pct": float(risk_data.get("daily_loss_remaining_pct", 100.0)),
            "weekly_loss_remaining_pct": float(risk_data.get("weekly_loss_remaining_pct", 100.0)),
            "emergency_locked": bool(risk_data.get("emergency_locked", False)),
            "reason_codes": risk_data.get("reason_codes", []),
        }

    async def _fetch_system(self) -> dict:
        from app.config import settings
        from app.services.freqtrade_client import FreqtradeClient
        from app.services.runtime_redis_store import RuntimeRedisStore

        ft = FreqtradeClient()
        store = RuntimeRedisStore(redis_url=settings.redis_url)

        ft_connected = await ft.ping()
        redis_ok = await store.ping()

        ft_state = "connected" if ft_connected else "disconnected"

        # Real latency probes (None → -1 means unavailable, never fake zeros)
        redis_rtt = await store.ping_rtt_ms()
        fast_track = await store.probe_fast_track_latency_ms()

        reason_codes: list[str] = []
        if store.is_degraded:
            reason_codes.append("redis_degraded_in_memory")
        if fast_track is None:
            reason_codes.append("fast_track_unavailable")

        return {
            "live_readiness_state": "live_ready" if (ft_connected and redis_ok) else "NOT_READY",
            "fast_track_latency_ms": fast_track if fast_track is not None else -1,
            "redis_rtt_ms": redis_rtt if redis_rtt is not None else -1,
            "freqtrade_state": ft_state,
            "exchange_state": _provider_category_state("cex"),
            "reason_codes": reason_codes,
        }

    async def _fetch_recent_decisions(self) -> list[dict]:
        """Fetch last 10 risk decisions from Ledger."""
        from app.database import SessionLocal
        from app.domain.ledger import ExecutionLedgerEvent
        from sqlalchemy import select

        db = SessionLocal()
        try:
            events = list(db.scalars(
                select(ExecutionLedgerEvent)
                .where(ExecutionLedgerEvent.event_type == "PULSEDESK_RISK_DECISION_CREATED")
                .order_by(ExecutionLedgerEvent.event_time.desc())
                .limit(10)
            ).all())
            return [
                {
                    "id": str(e.id),
                    "timestamp": e.event_time.isoformat() if e.event_time else "",
                    "decision": (e.normalized_payload or {}).get("decision", ""),
                    "symbol": (e.normalized_payload or {}).get("symbol", ""),
                }
                for e in events
            ]
        except Exception:
            return []
        finally:
            db.close()

    async def _fetch_alerts(self) -> list[dict]:
        """Fetch last 10 alert-level Ledger events."""
        from app.database import SessionLocal
        from app.domain.ledger import ExecutionLedgerEvent
        from sqlalchemy import select

        alert_types = [
            "CIRCUIT_BREAKER_TRIPPED",
            "FREQTRADE_RUN_DEGRADED",
            "PULSEDESK_COMMAND_FAILED",
        ]
        db = SessionLocal()
        try:
            events = list(db.scalars(
                select(ExecutionLedgerEvent)
                .where(ExecutionLedgerEvent.event_type.in_(alert_types))
                .order_by(ExecutionLedgerEvent.event_time.desc())
                .limit(10)
            ).all())
            return [
                {
                    "id": str(e.id),
                    "timestamp": e.event_time.isoformat() if e.event_time else "",
                    "type": e.event_type,
                    "message": ", ".join((e.normalized_payload or {}).get("reasons", [e.event_type])),
                }
                for e in events
            ]
        except Exception:
            return []
        finally:
            db.close()

        # ── State derivation ──────────────────────────────────────────────

    @staticmethod
    def _derive_state(risk: dict, system: dict) -> tuple[str, list[str]]:
        reason_codes: list[str] = []

        # Priority 1: emergency lock
        if risk.get("emergency_locked"):
            return "locked", ["emergency_locked"]

        # Priority 2: risk blocked/locked
        global_state = risk.get("global_state", "normal")
        if global_state in ("blocked", "locked"):
            reason_codes.append(f"risk_{global_state}")
            return "blocked", reason_codes

        # Priority 3: freqtrade disconnected
        ft_state = system.get("freqtrade_state", "unknown")
        if ft_state == "disconnected":
            reason_codes.append("freqtrade_disconnected")
            return "warning", reason_codes

        # Priority 4: risk warning
        if global_state == "warning":
            reason_codes.append("risk_warning")
            return "warning", reason_codes

        # All clear
        return "healthy", ["all_services_healthy"]

    @staticmethod
    def _derive_actions(state: str) -> list[dict]:
        """Return up to 3 contextual actions based on current state."""
        if state == "locked":
            return [
                {"type": "unlock_emergency", "enabled": True, "label": "Unlock Emergency Stop", "confirm_required": True},
            ]
        if state == "blocked":
            return [
                {"type": "review_risk", "enabled": True, "label": "Review Risk State", "confirm_required": False},
                {"type": "emergency_stop", "enabled": True, "label": "Emergency Stop", "confirm_required": True},
            ]
        if state == "warning":
            return [
                {"type": "review_warnings", "enabled": True, "label": "Review Warnings", "confirm_required": False},
                {"type": "tighten_stops", "enabled": True, "label": "Tighten Stop-Losses", "confirm_required": True},
                {"type": "emergency_stop", "enabled": True, "label": "Emergency Stop", "confirm_required": True},
            ]
        # healthy
        return [
            {"type": "deploy_strategy", "enabled": True, "label": "Deploy Strategy", "confirm_required": False},
            {"type": "review_signals", "enabled": True, "label": "Review Signals", "confirm_required": False},
            {"type": "start_paper", "enabled": True, "label": "Start Paper Trading", "confirm_required": False},
        ]

    # ── Helpers ───────────────────────────────────────────────────────

    @staticmethod
    def _safe_result(result: Any, default: Any) -> Any:
        if isinstance(result, BaseException):
            logger.warning("Sub-fetcher failed: %s", result)
            return default
        return result

    @staticmethod
    def _default_account() -> dict:
        return {
            "equity": 0, "currency": "USDT",
            "today_pnl_pct": 0.0, "week_pnl_pct": 0.0,
            "max_drawdown_pct": 0.0, "sharpe_ratio": 0.0,
        }

    @staticmethod
    def _default_runtime() -> dict:
        return {
            "running_strategies": 0, "open_positions": 0,
            "pending_orders": 0, "reconciling_count": 0,
        }

    @staticmethod
    def _default_risk() -> dict:
        return {
            "global_state": "normal",
            "daily_loss_remaining_pct": 100.0,
            "weekly_loss_remaining_pct": 100.0,
            "emergency_locked": False,
            "reason_codes": [],
        }

    @staticmethod
    def _default_system() -> dict:
        return {
            "live_readiness_state": "NOT_READY",
            "fast_track_latency_ms": -1,
            "redis_rtt_ms": -1,
            "freqtrade_state": "unknown",
            "exchange_state": "unknown",
            "reason_codes": ["system_probe_failed"],
        }
