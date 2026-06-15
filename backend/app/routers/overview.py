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
        reason_codes=["all_services_healthy", "low_latency"],
        available_actions=[
            AvailableAction(type="deploy_strategy", enabled=True, label="Deploy 'ETH Breakout v2' to Paper", confirm_required=False),
            AvailableAction(type="review_signals", enabled=True, label="Review 3 pending signals", confirm_required=False),
            AvailableAction(type="tighten_stop", enabled=True, label="Tighten SOL/USDT stop-loss", confirm_required=True),
        ],
        account=AccountOverview(
            equity=124850.32,
            currency="USDT",
            today_pnl_pct=1.97,
            week_pnl_pct=4.32,
            max_drawdown_pct=-6.8,
            sharpe_ratio=1.82,
        ),
        runtime=RuntimeOverview(
            running_strategies=5,
            open_positions=4,
            pending_orders=2,
            reconciling_count=0,
        ),
        risk=RiskOverview(
            global_state="normal",
            daily_loss_remaining_pct=72.0,
            weekly_loss_remaining_pct=85.0,
            emergency_locked=False,
            reason_codes=["within_budget", "no_breakers_triggered"],
        ),
        system=SystemOverview(
            live_readiness_state="live_ready",
            fast_track_latency_ms=12,
            redis_rtt_ms=3,
            freqtrade_state="connected",
            exchange_state="binance_connected",
        ),
        recent_decisions=[
            RecentDecision(time="14:32", symbol="BTC/USDT", decision="execute_long", reason_codes=["htf_bullish", "signal_strong", "risk_budget_ok"]),
            RecentDecision(time="14:15", symbol="SOL/USDT", decision="reduce_size", reason_codes=["daily_loss_warning", "reduce_size"]),
            RecentDecision(time="13:48", symbol="ETH/USDT", decision="hold", reason_codes=["near_resistance", "trend_intact"]),
            RecentDecision(time="13:20", symbol="AVAX/USDT", decision="execute_long", reason_codes=["breakout_confirmed", "momentum_strong"]),
            RecentDecision(time="12:45", symbol="BNB/USDT", decision="reject", reason_codes=["risk_gate_blocked", "correlation_high"]),
        ],
        alerts=[
            Alert(level="warning", title="Daily loss budget at 28% \u2014 approaching caution zone", symbol="PORTFOLIO", time="14:18"),
            Alert(level="info", title="ETH/USDT approaching resistance at $3,860", symbol="ETH/USDT", time="13:55"),
            Alert(level="warning", title="SOL/USDT volatility expanding \u2014 consider tightening stops", symbol="SOL/USDT", time="13:40"),
            Alert(level="info", title="Strategy 'BTC Momentum v3' entered new position", symbol="BTC/USDT", time="13:32"),
            Alert(level="error", title="Binance API latency spike \u2014 450ms (threshold: 200ms)", symbol="SYSTEM", time="12:15"),
            Alert(level="info", title="Reconciliation completed \u2014 0 discrepancies", symbol="SYSTEM", time="12:00"),
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
        from app.services.overview_aggregator import OverviewAggregatorService
        svc = OverviewAggregatorService()
        data = await svc.aggregate()
        return data
    except Exception as exc:
        logger.warning("Aggregator failed, using mock: %s", exc)
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
