from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

from app.domain.dsl import AccountRiskPolicy
from app.services.runtime_redis_store import RuntimeRedisStore

logger = logging.getLogger(__name__)

# Module-level manual block state, mirrored from system_settings on startup and
# on every write so a restart cannot silently re-enable new entries.
_manual_block_active: bool = False
_manual_block_reason: str | None = None

MANUAL_BLOCK_KEY = "risk.manual_block"
MANUAL_BLOCK_CATEGORY = "risk"


@dataclass
class AccountRiskState:
    allowed: bool
    decision: str
    reason_code: str
    daily_pnl: float = 0.0
    weekly_pnl: float = 0.0
    consecutive_losses: int = 0


class AccountRiskFirewall:
    MANUAL_BLOCK_KEY = MANUAL_BLOCK_KEY
    MANUAL_BLOCK_CATEGORY = MANUAL_BLOCK_CATEGORY

    def __init__(self, policy: Optional[AccountRiskPolicy] = None, redis_store: Optional[RuntimeRedisStore] = None):
        self._policy = policy or AccountRiskPolicy()
        self._store = redis_store
        self._states: dict[str, dict] = {}

    @classmethod
    def activate_manual_block(
        cls,
        reason: str = "manual",
        db=None,
        updated_by: str = "api",
    ) -> list[dict]:
        """Activate a manual block lock and persist it when a session is given."""
        global _manual_block_active, _manual_block_reason
        _manual_block_active = True
        _manual_block_reason = reason
        if db is not None:
            cls._persist(db, active=True, reason=reason, updated_by=updated_by)
        return cls.current_locks()

    @classmethod
    def deactivate_manual_block(cls, db=None, updated_by: str = "api") -> list[dict]:
        """Deactivate the manual block lock and persist the cleared state."""
        global _manual_block_active, _manual_block_reason
        _manual_block_active = False
        _manual_block_reason = None
        if db is not None:
            cls._persist(db, active=False, reason=None, updated_by=updated_by)
        return cls.current_locks()

    @classmethod
    def current_locks(cls) -> list[dict]:
        locks: list[dict] = []
        if _manual_block_active:
            locks.append({"lock": "manual_block", "reason": _manual_block_reason or "manual"})
        return locks

    # Backward-compatible alias for existing callers/tests.
    @classmethod
    def _current_locks(cls) -> list[dict]:
        return cls.current_locks()

    @classmethod
    def _persist(cls, db, *, active: bool, reason: str | None, updated_by: str) -> None:
        from app.services.system_settings import SystemSettingsService

        SystemSettingsService().upsert(
            db,
            MANUAL_BLOCK_KEY,
            {"active": active, "reason": reason},
            MANUAL_BLOCK_CATEGORY,
            updated_by=updated_by,
        )
        db.commit()

    @classmethod
    def load_persisted_block(cls, db=None) -> list[dict]:
        """Sync in-memory state from system_settings (called at startup)."""
        from app.database import SessionLocal
        from app.services.system_settings import SystemSettingsService

        global _manual_block_active, _manual_block_reason
        own_session = db is None
        session = db or SessionLocal()
        try:
            row = SystemSettingsService().get(session, MANUAL_BLOCK_KEY)
            value = (row.value or {}) if row is not None else {}
            _manual_block_active = bool(value.get("active"))
            _manual_block_reason = value.get("reason") if _manual_block_active else None
        except Exception:
            logger.exception("failed to load persisted manual block; keeping memory state")
        finally:
            if own_session:
                session.close()
        return cls.current_locks()

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

        if _manual_block_active:
            return AccountRiskState(
                allowed=False, decision="reject_order",
                reason_code="manual_block_active",
                daily_pnl=state.get("daily_pnl", 0.0),
                weekly_pnl=state.get("weekly_pnl", 0.0),
                consecutive_losses=state.get("consecutive_losses", 0),
            )

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
