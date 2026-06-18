"""Overview BFF — Dashboard + Live Readiness + Global Status

Production policy (v2.5 mock-removal): when the underlying service is
unavailable we return an explicit `data_source_unavailable` state with
empty payload + reason_codes, NOT a hardcoded mock. Frontend must
inspect `state` / `reason_codes` and render an empty/error state.
"""
import logging

from fastapi import APIRouter

from app.schemas.overview import (
    DashboardResponse, LiveReadinessResponse, GlobalStatusResponse,
    AccountOverview, RuntimeOverview, RiskOverview, SystemOverview,
    RecentDecision, Alert, ReadinessCheck,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/overview", tags=["overview-bff"])
logger = logging.getLogger(__name__)


_UNAVAILABLE_REASON = "data_source_unavailable"


def _empty_dashboard(reason: str) -> dict:
    return DashboardResponse(
        state="data_source_unavailable",
        reason_codes=[reason, _UNAVAILABLE_REASON],
        available_actions=[],
        account=AccountOverview(
            equity=0, currency="USDT",
            today_pnl_pct=0, week_pnl_pct=0,
            max_drawdown_pct=0, sharpe_ratio=0,
        ),
        runtime=RuntimeOverview(
            running_strategies=0, open_positions=0,
            pending_orders=0, reconciling_count=0,
        ),
        risk=RiskOverview(
            global_state="unknown",
            daily_loss_remaining_pct=0,
            weekly_loss_remaining_pct=0,
            emergency_locked=False,
            reason_codes=[_UNAVAILABLE_REASON],
        ),
        system=SystemOverview(
            live_readiness_state="unknown",
            fast_track_latency_ms=None,
            redis_rtt_ms=None,
            freqtrade_state="unknown",
            exchange_state="unknown",
        ),
        recent_decisions=[],
        alerts=[],
    ).model_dump()


def _empty_live_readiness(reason: str) -> dict:
    return LiveReadinessResponse(
        state="data_source_unavailable",
        grand_status="not_live",
        score=0,
        reason_codes=[reason, _UNAVAILABLE_REASON],
        available_actions=[],
        can_start_paper=False,
        can_start_live_small=False,
        can_start_full_live=False,
        blocking_reasons=[{"code": _UNAVAILABLE_REASON, "message": reason}],
        warnings=[],
        checks=[],
        selected_mode="",
        selected_strategy_id="",
        selected_capital_pool_id="",
        selected_exchange="",
        available_strategies=[],
        available_capital_pools=[],
        available_exchanges=_list_available_exchanges(),
    ).model_dump()


def _empty_global_status(reason: str) -> dict:
    return GlobalStatusResponse(
        system_state="data_source_unavailable",
        risk_state="unknown",
        fast_track_latency_ms=None,
        freqtrade_state="unknown",
        redis_rtt_ms=None,
        exchange_state="unknown",
        open_positions=0,
        emergency_locked=False,
    ).model_dump()


@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard():
    try:
        from app.services.overview_aggregator import OverviewAggregatorService
        svc = OverviewAggregatorService()
        data = await svc.aggregate()
        return data
    except Exception as exc:
        logger.exception("Aggregator failed, returning data_source_unavailable: %s", exc)
        return _empty_dashboard(reason=type(exc).__name__)


@router.get("/live-readiness", response_model=LiveReadinessResponse)
async def get_live_readiness(
    mode: str = "live_small",
    strategy_id: str = "",
    capital_pool_id: str = "",
    exchange: str = "binance",
):
    try:
        from app.services.live_readiness_service import LiveReadinessService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.services.freqtrade_client import FreqtradeClient
        from app.config import settings
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        ft = FreqtradeClient(base_url=settings.freqtrade_url)
        svc = LiveReadinessService(redis_store=store, freqtrade_client=ft)
        result = await svc.evaluate(
            selected_mode=mode,
            selected_strategy_id=strategy_id,
            selected_capital_pool_id=capital_pool_id,
            selected_exchange=exchange,
        )
        return _build_live_readiness_response(result)
    except Exception as e:
        logger.exception(f"[live-readiness] LiveReadinessService unavailable: {e}")
        return _empty_live_readiness(reason=type(e).__name__)


@router.post("/live-readiness/check", response_model=LiveReadinessResponse)
async def run_readiness_check(body: dict = {}):
    try:
        from app.services.live_readiness_service import LiveReadinessService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.services.freqtrade_client import FreqtradeClient
        from app.config import settings
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        ft = FreqtradeClient(base_url=settings.freqtrade_url)
        svc = LiveReadinessService(redis_store=store, freqtrade_client=ft)
        result = await svc.evaluate(
            selected_mode=body.get("mode", "live_small"),
            selected_strategy_id=body.get("strategy_id", ""),
            selected_capital_pool_id=body.get("capital_pool_id", ""),
            selected_exchange=body.get("exchange", "binance"),
        )
        return _build_live_readiness_response(result)
    except Exception as e:
        logger.exception(f"[live-readiness-check] LiveReadinessService unavailable: {e}")
        return _empty_live_readiness(reason=type(e).__name__)


def _build_live_readiness_response(result) -> dict:
    return {
        "state": result.state,
        "grand_status": result.grand_status,
        "score": result.score,
        "reason_codes": result.reason_codes,
        "available_actions": [
            {"type": "start_paper", "enabled": result.can_start_paper, "label": "启动模拟"},
            {"type": "start_live_small", "enabled": result.can_start_live_small, "label": "启动小仓实盘", "confirm_required": True},
            {"type": "start_live_full", "enabled": result.can_start_full_live, "label": "启动全仓实盘", "confirm_required": True},
        ],
        "can_start_paper": result.can_start_paper,
        "can_start_live_small": result.can_start_live_small,
        "can_start_full_live": result.can_start_full_live,
        "blocking_reasons": result.blocking_reasons,
        "warnings": result.warnings,
        "checks": [
            {
                "key": c.key, "label": c.label, "status": c.status,
                "value": c.value, "threshold": c.threshold,
                "detail": c.detail, "group": c.group,
            }
            for c in result.checks
        ],
        "selected_mode": result.selected_mode,
        "selected_strategy_id": result.selected_strategy_id,
        "selected_capital_pool_id": result.selected_capital_pool_id,
        "selected_exchange": result.selected_exchange,
        "available_strategies": _list_available_strategies(),
        "available_capital_pools": _list_available_capital_pools(),
        "available_exchanges": _list_available_exchanges(),
    }


def _list_available_strategies() -> list[dict]:
    """Best-effort list of strategies (read from DB if available)."""
    try:
        from app.database import get_db
        from app.domain.strategy import Strategy
        from sqlalchemy import select
        db = next(get_db())
        try:
            rows = list(db.scalars(select(Strategy).limit(20)).all())
            return [
                {
                    "id": str(s.id), "name": getattr(s, "name", ""),
                    "version": getattr(s, "version", 1),
                    "status": getattr(s, "status", "draft"),
                }
                for s in rows
            ]
        finally:
            db.close()
    except Exception as e:
        logger.debug(f"[live-readiness] strategy list unavailable: {e}")
        return []


def _list_available_capital_pools() -> list[dict]:
    try:
        from app.database import get_db
        from app.domain.risk import CapitalPool
        from sqlalchemy import select
        db = next(get_db())
        try:
            rows = list(db.scalars(select(CapitalPool).limit(10)).all())
            return [
                {
                    "id": str(p.id), "name": getattr(p, "name", "default"),
                    "total_budget": float(getattr(p, "total_budget", 0) or 0),
                    "max_daily_loss_pct": float(getattr(p, "max_daily_loss_pct", 0) or 0),
                }
                for p in rows
            ]
        finally:
            db.close()
    except Exception as e:
        logger.debug(f"[live-readiness] capital pool list unavailable: {e}")
        return []


def _list_available_exchanges() -> list[dict]:
    return [
        {"id": "binance", "name": "Binance", "kind": "cex"},
        {"id": "okx", "name": "OKX", "kind": "cex"},
        {"id": "bybit", "name": "Bybit", "kind": "cex"},
    ]


@router.get("/global-status", response_model=GlobalStatusResponse)
async def get_global_status():
    try:
        from app.services.bff.overview_aggregator import OverviewAggregator
        agg = OverviewAggregator()
        return await agg.global_status()
    except Exception as e:
        logger.exception(f"[global-status] OverviewAggregator unavailable: {e}")
        return _empty_global_status(reason=type(e).__name__)
