"""Risk BFF Aggregator"""
from __future__ import annotations

import logging

from app.config import settings
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.stop_protection_service import StopProtectionService
from app.services.volatility_lock_service import VolatilityLockService
from app.domain.dsl import AccountRiskPolicy

logger = logging.getLogger(__name__)


class RiskAggregator:
    def __init__(self):
        self._store = RuntimeRedisStore(redis_url=settings.redis_url)
        self._firewall = AccountRiskFirewall(
            policy=AccountRiskPolicy(),
            redis_store=self._store,
        )
        self._stop_svc = StopProtectionService(redis_store=self._store)
        self._vol_svc = VolatilityLockService(redis_store=self._store)

    async def overview(self, account_id: str = "default") -> dict:
        risk_state = await self._firewall.check(account_id)
        policy = self._firewall._policy

        guards = [
            {
                "key": "daily_loss", "label": "日亏损限制",
                "current_value": abs(risk_state.daily_pnl),
                "limit_value": policy.max_daily_loss,
                "remaining_pct": max(0, 1 - abs(risk_state.daily_pnl) / policy.max_daily_loss),
                "status": "healthy" if risk_state.daily_pnl == 0 or abs(risk_state.daily_pnl) < policy.max_daily_loss * 0.8 else "warning",
                "reason_codes": [],
            },
            {
                "key": "weekly_loss", "label": "周亏损限制",
                "current_value": abs(risk_state.weekly_pnl),
                "limit_value": policy.max_weekly_loss,
                "remaining_pct": max(0, 1 - abs(risk_state.weekly_pnl) / policy.max_weekly_loss),
                "status": "healthy" if abs(risk_state.weekly_pnl) < policy.max_weekly_loss * 0.8 else "warning",
                "reason_codes": [],
            },
            {
                "key": "consecutive_loss", "label": "连续亏损",
                "current_value": risk_state.consecutive_losses,
                "limit_value": policy.max_consecutive_losses,
                "remaining_pct": max(0, 1 - risk_state.consecutive_losses / policy.max_consecutive_losses),
                "status": "healthy" if risk_state.consecutive_losses < policy.max_consecutive_losses * 0.8 else "warning",
                "reason_codes": [],
            },
        ]

        return {
            "state": risk_state.decision if not risk_state.allowed else "normal",
            "reason_codes": [risk_state.reason_code] if not risk_state.allowed else [],
            "available_actions": [
                {"type": "emergency_stop", "enabled": True, "label": "紧急停止", "confirm_required": True},
                {"type": "block_new_entries", "enabled": risk_state.allowed, "label": "禁止新开仓"},
                {"type": "unblock", "enabled": not risk_state.allowed, "label": "解除禁止"},
            ],
            "account_state": risk_state.decision,
            "emergency_locked": risk_state.reason_code == "kill_switch_active",
            "guards": guards,
            "active_locks": [],
        }
