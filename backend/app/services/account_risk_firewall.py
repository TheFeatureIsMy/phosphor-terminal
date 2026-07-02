from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

from app.domain.dsl import AccountRiskPolicy
from app.services.runtime_redis_store import RuntimeRedisStore

logger = logging.getLogger(__name__)

# Module-level manual block state (persists across request-scoped instances)
_manual_block_active: bool = False
_manual_block_reason: str | None = None


@dataclass
class AccountRiskState:
    allowed: bool
    decision: str
    reason_code: str
    daily_pnl: float = 0.0
    weekly_pnl: float = 0.0
    consecutive_losses: int = 0


class AccountRiskFirewall:
    def __init__(self, policy: Optional[AccountRiskPolicy] = None, redis_store: Optional[RuntimeRedisStore] = None):
        self._policy = policy
        self._store = redis_store
        self._states: dict[str, dict] = {}

    @classmethod
    def activate_manual_block(cls, reason: str = "manual") -> list[dict]:
        """Activate a manual block lock. Returns current active_locks list."""
        global _manual_block_active, _manual_block_reason
        _manual_block_active = True
        _manual_block_reason = reason
        return cls._current_locks()

    @classmethod
    def deactivate_manual_block(cls) -> list[dict]:
        """Deactivate the manual block lock. Returns current active_locks list."""
        global _manual_block_active, _manual_block_reason
        _manual_block_active = False
        _manual_block_reason = None
        return cls._current_locks()

    @classmethod
    def _current_locks(cls) -> list[dict]:
        locks: list[dict] = []
        if _manual_block_active:
            locks.append({"lock": "manual_block", "reason": _manual_block_reason or "manual"})
        return locks

    async def _load_state(self, account_id: str) -> dict:
        if self._store:
            cached = await self._store.read_account_risk_state(account_id)
            if cached:
                return cached
        return self._states.get(account_id, {
            "daily_pnl": 0.0,
            "weekly_pnl": 0.0,
            "consecutive_losses": 0,
            "kill_switch": False,
        })

    async def _save_state(self, account_id: str, state: dict) -> None:
        self._states[account_id] = state
        if self._store:
            await self._store.write_account_risk_state(account_id, state, ttl=86400)

    async def check(self, account_id: str) -> AccountRiskState:
        state = await self._load_state(account_id)

        if state.get("kill_switch"):
            return AccountRiskState(
                allowed=False, decision="reject_order",
                reason_code="kill_switch_active",
                daily_pnl=state["daily_pnl"],
                weekly_pnl=state["weekly_pnl"],
                consecutive_losses=state["consecutive_losses"],
            )

        if abs(state["daily_pnl"]) >= self._policy.max_daily_loss:
            return AccountRiskState(
                allowed=False, decision="reject_order",
                reason_code="daily_loss_limit_reached",
                daily_pnl=state["daily_pnl"],
                weekly_pnl=state["weekly_pnl"],
                consecutive_losses=state["consecutive_losses"],
            )

        if abs(state["weekly_pnl"]) >= self._policy.max_weekly_loss:
            return AccountRiskState(
                allowed=False, decision="reject_order",
                reason_code="weekly_loss_limit_reached",
                daily_pnl=state["daily_pnl"],
                weekly_pnl=state["weekly_pnl"],
                consecutive_losses=state["consecutive_losses"],
            )

        if state["consecutive_losses"] >= self._policy.max_consecutive_losses:
            return AccountRiskState(
                allowed=False, decision="reject_order",
                reason_code="consecutive_loss_limit_reached",
                daily_pnl=state["daily_pnl"],
                weekly_pnl=state["weekly_pnl"],
                consecutive_losses=state["consecutive_losses"],
            )

        return AccountRiskState(
            allowed=True, decision="allow",
            reason_code="account_risk_allowed",
            daily_pnl=state["daily_pnl"],
            weekly_pnl=state["weekly_pnl"],
            consecutive_losses=state["consecutive_losses"],
        )

    async def record_trade_result(self, account_id: str, pnl: float, is_loss: bool) -> None:
        state = await self._load_state(account_id)
        state["daily_pnl"] = state.get("daily_pnl", 0.0) + pnl
        state["weekly_pnl"] = state.get("weekly_pnl", 0.0) + pnl
        if is_loss:
            state["consecutive_losses"] = state.get("consecutive_losses", 0) + 1
        else:
            state["consecutive_losses"] = 0
        await self._save_state(account_id, state)

    async def reset_daily(self, account_id: str) -> None:
        state = await self._load_state(account_id)
        state["daily_pnl"] = 0.0
        state["consecutive_losses"] = 0
        state["kill_switch"] = False
        await self._save_state(account_id, state)

    async def activate_kill_switch(self, account_id: str) -> None:
        state = await self._load_state(account_id)
        state["kill_switch"] = True
        await self._save_state(account_id, state)
