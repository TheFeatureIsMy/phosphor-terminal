"""Overview BFF Aggregator — Dashboard + Global Status"""
from __future__ import annotations

import logging

from app.config import settings
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.freqtrade_client import FreqtradeClient
from app.domain.dsl import AccountRiskPolicy

logger = logging.getLogger(__name__)


class OverviewAggregator:
    def __init__(self):
        self._store = RuntimeRedisStore(redis_url=settings.redis_url)
        self._ft = FreqtradeClient(base_url=settings.freqtrade_url)
        self._firewall = AccountRiskFirewall(
            policy=AccountRiskPolicy(),
            redis_store=self._store,
        )

    async def global_status(self) -> dict:
        cached = await self._store.read_global_status()
        if cached:
            return cached

        # Gather real state
        redis_ok = await self._store.ping()
        risk_state = await self._firewall.check("default")
        ft_state = "unknown"
        try:
            version = await self._ft.version()
            ft_state = "healthy" if version else "unavailable"
        except Exception:
            ft_state = "unavailable"

        reason_codes = []
        if not risk_state.allowed:
            reason_codes.append(risk_state.reason_code)
        if ft_state != "healthy":
            reason_codes.append("freqtrade_unavailable")

        # Determine system state
        if risk_state.reason_code == "kill_switch_active":
            system_state = "EMERGENCY_LOCKED"
        elif not risk_state.allowed:
            system_state = "RISK_LOCKED"
        elif ft_state != "healthy":
            system_state = "PAPER_ONLY"
        else:
            system_state = "LIVE_SMALL_READY"

        status = {
            "system_state": system_state,
            "risk_state": "blocked" if not risk_state.allowed else "normal",
            "fast_track_latency_ms": 0,
            "freqtrade_state": ft_state,
            "redis_rtt_ms": 0 if redis_ok else -1,
            "exchange_state": "ok",
            "open_positions": 0,
            "emergency_locked": risk_state.reason_code == "kill_switch_active",
            "reason_codes": reason_codes,
        }

        await self._store.write_global_status(status, ttl=10)
        return status

    async def dashboard(self) -> dict:
        global_status = await self.global_status()
        risk_state = await self._firewall.check("default")

        return {
            "state": "healthy" if risk_state.allowed else "blocked",
            "reason_codes": global_status.get("reason_codes", []),
            "available_actions": [
                {"type": "emergency_stop", "enabled": True, "label": "紧急停止", "confirm_required": True},
            ],
            "account": {
                "equity": 0, "currency": "USDT",
                "today_pnl_pct": 0, "week_pnl_pct": 0, "max_drawdown_pct": 0,
            },
            "runtime": {
                "running_strategies": 0, "open_positions": 0,
                "pending_orders": 0, "reconciling_count": 0,
            },
            "risk": {
                "global_state": "blocked" if not risk_state.allowed else "normal",
                "daily_loss_remaining_pct": max(0, 1 - abs(risk_state.daily_pnl) / 500) if risk_state.daily_pnl else 1.0,
                "weekly_loss_remaining_pct": max(0, 1 - abs(risk_state.weekly_pnl) / 1500) if risk_state.weekly_pnl else 1.0,
                "emergency_locked": risk_state.reason_code == "kill_switch_active",
                "reason_codes": [risk_state.reason_code] if not risk_state.allowed else [],
            },
            "system": {
                "live_readiness_state": global_status.get("system_state", "NOT_READY"),
                "fast_track_latency_ms": global_status.get("fast_track_latency_ms", 0),
                "redis_rtt_ms": global_status.get("redis_rtt_ms", 0),
                "freqtrade_state": global_status.get("freqtrade_state", "unknown"),
                "exchange_state": global_status.get("exchange_state", "unknown"),
            },
            "recent_decisions": [],
            "alerts": [],
        }
