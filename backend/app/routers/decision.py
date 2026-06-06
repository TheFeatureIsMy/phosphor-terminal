from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.config import settings
from app.domain.dsl import AccountRiskPolicy
from app.schemas.decision import RiskStateResponse, KillSwitchRequest
from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.heartbeat_monitor import HeartbeatMonitor
from app.services.runtime_redis_store import RuntimeRedisStore

router = APIRouter(prefix="/api/v3/decision", tags=["decision"])

_store: RuntimeRedisStore | None = None
_firewall: AccountRiskFirewall | None = None
_heartbeat: HeartbeatMonitor | None = None


def _get_store() -> RuntimeRedisStore:
    global _store
    if _store is None:
        _store = RuntimeRedisStore(redis_url=settings.redis_url)
    return _store


def _get_firewall() -> AccountRiskFirewall:
    global _firewall
    if _firewall is None:
        _firewall = AccountRiskFirewall(
            policy=AccountRiskPolicy(),
            redis_store=_get_store(),
        )
    return _firewall


def _get_heartbeat() -> HeartbeatMonitor:
    global _heartbeat
    if _heartbeat is None:
        _heartbeat = HeartbeatMonitor(redis_store=_get_store())
    return _heartbeat


@router.get("/snapshot/{strategy_id}/{symbol}/{timeframe}")
async def get_snapshot(strategy_id: str, symbol: str, timeframe: str):
    store = _get_store()
    snap = await store.read_snapshot(strategy_id, symbol, timeframe)
    if not snap:
        raise HTTPException(status_code=404, detail="no active snapshot")
    return snap


@router.get("/risk-state/{account_id}", response_model=RiskStateResponse)
async def get_risk_state(account_id: str):
    firewall = _get_firewall()
    state = await firewall.check(account_id)
    return RiskStateResponse(
        allowed=state.allowed, decision=state.decision,
        reason_code=state.reason_code, daily_pnl=state.daily_pnl,
        weekly_pnl=state.weekly_pnl, consecutive_losses=state.consecutive_losses,
    )


@router.post("/kill-switch/{account_id}")
async def toggle_kill_switch(account_id: str, body: KillSwitchRequest):
    firewall = _get_firewall()
    if body.activate:
        await firewall.activate_kill_switch(account_id)
        return {"status": "kill_switch_activated"}
    await firewall.reset_daily(account_id)
    return {"status": "kill_switch_deactivated"}


@router.post("/heartbeat/{strategy_id}")
async def record_heartbeat(strategy_id: str):
    monitor = _get_heartbeat()
    await monitor.record_heartbeat(strategy_id)
    return {"status": "ok"}


@router.get("/heartbeat/{strategy_id}")
async def get_heartbeat(strategy_id: str):
    monitor = _get_heartbeat()
    status = await monitor.check_alive(strategy_id)
    return {
        "alive": status.alive,
        "last_seen_at": status.last_seen_at.isoformat() if status.last_seen_at else None,
        "stale_seconds": status.stale_seconds,
    }
