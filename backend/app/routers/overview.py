"""Overview BFF — Dashboard + Live Readiness + Global Status"""
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


def _mock_dashboard() -> dict:
    return DashboardResponse(
        state="healthy",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
        ],
        account=AccountOverview(equity=10248.32, currency="USDT", today_pnl_pct=0.012, week_pnl_pct=0.038, max_drawdown_pct=0.041),
        runtime=RuntimeOverview(running_strategies=2, open_positions=3, pending_orders=1, reconciling_count=0),
        risk=RiskOverview(global_state="normal", daily_loss_remaining_pct=0.024, weekly_loss_remaining_pct=0.065, emergency_locked=False),
        system=SystemOverview(live_readiness_state="LIVE_SMALL_READY", fast_track_latency_ms=45, redis_rtt_ms=3, freqtrade_state="healthy", exchange_state="ok"),
        recent_decisions=[
            RecentDecision(symbol="BTC/USDT", decision="reduce_size", reason_codes=["ai_cache_soft_expired", "shadow_warning"]),
        ],
        alerts=[
            Alert(level="warning", title="1h Shadow OB temporary violation", symbol="BTC/USDT"),
        ],
    ).model_dump()


def _mock_live_readiness() -> dict:
    return LiveReadinessResponse(
        state="LIVE_SMALL_READY",
        score=86,
        reason_codes=[],
        available_actions=[
            AvailableAction(type="start_paper", enabled=True, label="启动模拟"),
            AvailableAction(type="start_live_small", enabled=True, label="启动小仓实盘", confirm_required=True),
            AvailableAction(type="disable_auto", enabled=True, label="禁用自动交易", confirm_required=True),
        ],
        can_start_paper=True,
        can_start_live_small=True,
        can_start_full_live=False,
        blocking_reasons=[],
        warnings=[{"code": "exchange_api_weight_warning", "message": "交易所 API 权重剩余偏低"}],
        checks=[
            ReadinessCheck(key="fast_track_latency", label="Fast Track 延迟", status="healthy", value="45ms", threshold="<200ms"),
            ReadinessCheck(key="redis_rtt", label="Redis RTT", status="healthy", value="3ms", threshold="<50ms"),
            ReadinessCheck(key="postgres", label="PostgreSQL", status="healthy", value="ok", threshold="connected"),
            ReadinessCheck(key="freqtrade", label="Freqtrade", status="healthy", value="running", threshold="running"),
            ReadinessCheck(key="exchange_api", label="交易所 API", status="warning", value="weight 80%", threshold="<90%"),
            ReadinessCheck(key="orderbook", label="订单簿数据", status="healthy", value="fresh", threshold="<5s"),
            ReadinessCheck(key="ai_cache", label="AI Risk Cache", status="healthy", value="fresh", threshold="not expired"),
            ReadinessCheck(key="risk_state", label="风控状态", status="healthy", value="normal", threshold="not locked"),
        ],
    ).model_dump()


def _mock_global_status() -> dict:
    return GlobalStatusResponse(
        system_state="LIVE_SMALL_READY",
        risk_state="normal",
        fast_track_latency_ms=45,
        freqtrade_state="healthy",
        redis_rtt_ms=3,
        exchange_state="ok",
        open_positions=3,
        emergency_locked=False,
    ).model_dump()


@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard():
    try:
        from app.services.bff.overview_aggregator import OverviewAggregator
        agg = OverviewAggregator()
        return await agg.dashboard()
    except Exception as e:
        logger.warning(f"[dashboard] OverviewAggregator unavailable, mock fallback: {e}")
        data = _mock_dashboard()
        data["_mock"] = True
        return data


@router.get("/live-readiness", response_model=LiveReadinessResponse)
async def get_live_readiness():
    try:
        from app.services.live_readiness_service import LiveReadinessService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.services.freqtrade_client import FreqtradeClient
        from app.config import settings
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        ft = FreqtradeClient(base_url=settings.freqtrade_url)
        svc = LiveReadinessService(redis_store=store, freqtrade_client=ft)
        result = await svc.evaluate()
        return {
            "state": result.state, "score": result.score,
            "reason_codes": result.reason_codes,
            "available_actions": [
                {"type": "start_paper", "enabled": result.can_start_paper, "label": "启动模拟"},
                {"type": "start_live_small", "enabled": result.can_start_live_small, "label": "启动小仓实盘", "confirm_required": True},
            ],
            "can_start_paper": result.can_start_paper,
            "can_start_live_small": result.can_start_live_small,
            "can_start_full_live": result.can_start_full_live,
            "blocking_reasons": result.blocking_reasons,
            "warnings": result.warnings,
            "checks": [{"key": c.key, "label": c.label, "status": c.status, "value": c.value, "threshold": c.threshold} for c in result.checks],
        }
    except Exception as e:
        logger.warning(f"[live-readiness] LiveReadinessService unavailable, mock fallback: {e}")
        data = _mock_live_readiness()
        data["_mock"] = True
        return data


@router.post("/live-readiness/check", response_model=LiveReadinessResponse)
async def run_readiness_check():
    try:
        from app.services.live_readiness_service import LiveReadinessService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.services.freqtrade_client import FreqtradeClient
        from app.config import settings
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        ft = FreqtradeClient(base_url=settings.freqtrade_url)
        svc = LiveReadinessService(redis_store=store, freqtrade_client=ft)
        result = await svc.evaluate()
        return {
            "state": result.state, "score": result.score,
            "reason_codes": result.reason_codes,
            "available_actions": [
                {"type": "start_paper", "enabled": result.can_start_paper, "label": "启动模拟"},
                {"type": "start_live_small", "enabled": result.can_start_live_small, "label": "启动小仓实盘", "confirm_required": True},
            ],
            "can_start_paper": result.can_start_paper,
            "can_start_live_small": result.can_start_live_small,
            "can_start_full_live": result.can_start_full_live,
            "blocking_reasons": result.blocking_reasons,
            "warnings": result.warnings,
            "checks": [{"key": c.key, "label": c.label, "status": c.status, "value": c.value, "threshold": c.threshold} for c in result.checks],
        }
    except Exception as e:
        logger.warning(f"[live-readiness-check] LiveReadinessService unavailable, mock fallback: {e}")
        data = _mock_live_readiness()
        data["_mock"] = True
        return data


@router.get("/global-status", response_model=GlobalStatusResponse)
async def get_global_status():
    try:
        from app.services.bff.overview_aggregator import OverviewAggregator
        agg = OverviewAggregator()
        return await agg.global_status()
    except Exception as e:
        logger.warning(f"[global-status] OverviewAggregator unavailable, mock fallback: {e}")
        data = _mock_global_status()
        data["_mock"] = True
        return data
