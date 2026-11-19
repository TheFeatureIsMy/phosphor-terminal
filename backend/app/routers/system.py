import logging
import os
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.models.user import User
from app.security.deps import get_current_tenant_id, get_optional_user
from app.services.freqtrade_client import freqtrade_client
from app.schemas.api import SystemStatusResponse

router = APIRouter(prefix="/api/system", tags=["system"])
logger = logging.getLogger(__name__)


def _execution_counts() -> tuple[int, int]:
    """Return (active_strategy_runs, open_orders) from the database."""
    from sqlalchemy import func, select

    from app.database import SessionLocal
    from app.domain.execution import StrategyRun
    from app.domain.order import ExecutionOrder

    db = SessionLocal()
    try:
        active = db.scalar(
            select(func.count()).select_from(StrategyRun).where(
                StrategyRun.status.in_(["running", "starting"])
            )
        ) or 0
        open_orders = db.scalar(
            select(func.count()).select_from(ExecutionOrder).where(
                ExecutionOrder.status == "open"
            )
        ) or 0
        return int(active), int(open_orders)
    except Exception:
        logger.exception("failed to read execution counts")
        return 0, 0
    finally:
        db.close()


@router.get("/status", response_model=SystemStatusResponse)
async def get_system_status():
    try:
        ft_status = await freqtrade_client.get_status()
        api_ok = freqtrade_client.is_success(ft_status)
        open_pos = len(ft_status) if isinstance(ft_status, list) else 0
        detail = None if api_ok else str(ft_status.get("error") if isinstance(ft_status, dict) else "Unknown Freqtrade error")
    except Exception as exc:
        api_ok = False
        open_pos = 0
        detail = str(exc)

    active_strategies, pending_orders = _execution_counts()
    return SystemStatusResponse(
        uptime="unknown" if not api_ok else "connected",
        active_strategies=active_strategies,
        open_positions=open_pos,
        pending_orders=pending_orders,
        last_data_update=datetime.now(timezone.utc),
        api_status="connected" if api_ok else "disconnected",
        data_source={
            "source": "freqtrade" if api_ok else "unavailable",
            "simulated": False,
            "available": api_ok,
            "detail": detail,
        },
    )


@router.get("/command-queue")
def get_command_queue(
    scope: str = Query(default="tenant", pattern="^(tenant|platform)$"),
    tenant_raw: str | None = Depends(get_current_tenant_id),
    user: User | None = Depends(get_optional_user),
):
    """Command Bus queue depth, tenant-scoped unless a superuser asks for platform."""
    from datetime import timedelta

    from sqlalchemy import func, select

    from app.database import SessionLocal
    from app.domain.command import CommandBusCommand

    try:
        tenant_id = int(tenant_raw) if tenant_raw is not None else None
    except (TypeError, ValueError):
        tenant_id = None
    platform = scope == "platform" and user is not None and user.is_superuser
    queue_scope = "platform" if platform else "tenant"
    filters = []
    if not platform and tenant_id is not None:
        filters.append(CommandBusCommand.tenant_id == tenant_id)

    db = SessionLocal()
    try:
        count_query = select(CommandBusCommand.status, func.count()).group_by(
            CommandBusCommand.status
        )
        if filters:
            count_query = count_query.where(*filters)
        rows = db.execute(count_query).all()
        counts = {status: int(count) for status, count in rows}
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        oldest_query = select(func.min(CommandBusCommand.created_at)).where(
            CommandBusCommand.status.in_(["pending", "retry_waiting"])
        )
        if filters:
            oldest_query = oldest_query.where(*filters)
        oldest = db.scalar(oldest_query)
        if oldest is not None and oldest.tzinfo is not None:
            oldest = oldest.astimezone(timezone.utc).replace(tzinfo=None)
        stuck_query = select(func.count()).select_from(CommandBusCommand).where(
            CommandBusCommand.status == "running",
            CommandBusCommand.locked_at.isnot(None),
            CommandBusCommand.locked_at < now - timedelta(minutes=10),
        )
        if filters:
            stuck_query = stuck_query.where(*filters)
        stuck = db.scalar(stuck_query) or 0
        return {
            "scope": queue_scope,
            "tenant_id": tenant_id,
            "counts": counts,
            "oldest_pending_at": oldest.isoformat() if oldest else None,
            "oldest_pending_age_s": int((now - oldest).total_seconds()) if oldest else None,
            "running": counts.get("running", 0),
            "stuck_running": int(stuck),
            "state": "degraded" if stuck else "healthy",
            "reason_codes": ["stuck_commands"] if stuck else [],
        }
    except Exception:
        logger.exception("failed to read command queue stats")
        return {
            "scope": queue_scope,
            "tenant_id": tenant_id,
            "counts": {},
            "oldest_pending_at": None,
            "oldest_pending_age_s": None,
            "running": 0,
            "stuck_running": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable"],
        }
    finally:
        db.close()


@router.get("/dependencies")
async def get_dependencies():
    from app.services.dependency_checker import check_all_dependencies

    return check_all_dependencies()


@router.get("/fast-track-health")
async def get_fast_track_health():
    """Fast-track latency / data-freshness health for the Structure page."""
    import time

    latency_ms = 0
    redis_ok = False
    try:
        import redis
        from app.config import settings

        r = redis.Redis.from_url(settings.redis_url, socket_connect_timeout=2)
        t0 = time.perf_counter()
        r.ping()
        latency_ms = int((time.perf_counter() - t0) * 1000)
        redis_ok = True
    except Exception:
        redis_ok = False

    return {
        "latency_ms": latency_ms,
        "data_age_seconds": 0.0,
        "redis_ok": redis_ok,
        "verdict_trustworthy": redis_ok,
    }


# ── Unified Service Status ───────────────────────────────────────────


def _check_redis() -> dict:
    try:
        import redis
        from app.config import settings
        r = redis.Redis.from_url(settings.redis_url, socket_connect_timeout=2)
        r.ping()
        info = r.info()
        return {
            "status": "connected",
            "version": info.get("redis_version", "unknown"),
            "used_memory_mb": round(info.get("used_memory", 0) / 1024 / 1024, 1),
            "connected_clients": info.get("connected_clients", 0),
        }
    except Exception as e:
        return {"status": "disconnected", "error": str(e)}


def _check_database() -> dict:
    try:
        from app.database import check_db
        ok = check_db()
        return {"status": "connected" if ok else "disconnected"}
    except Exception as e:
        return {"status": "disconnected", "error": str(e)}


async def _check_freqtrade() -> dict:
    try:
        ft_status = await freqtrade_client.get_status()
        ok = freqtrade_client.is_success(ft_status)
        open_pos = len(ft_status) if isinstance(ft_status, list) else 0
        return {"status": "connected" if ok else "disconnected", "open_positions": open_pos}
    except Exception as e:
        return {"status": "disconnected", "error": str(e)}


@router.get("/services")
async def get_service_status():
    """Unified service health overview for the Service Management page."""
    from app.services.dependency_checker import _check_ollama, _llm_provider_db_status

    services = {
        "backend": {"status": "connected", "detail": "API responding"},
        "database": _check_database(),
        "redis": _check_redis(),
        "freqtrade": await _check_freqtrade(),
        "ollama": _check_ollama(),
        "openai": _llm_provider_db_status("openai"),
        "anthropic": _llm_provider_db_status("anthropic"),
        "deepseek": _llm_provider_db_status("deepseek"),
        "telegram": {
            "status": "configured" if os.environ.get("TELEGRAM_BOT_TOKEN") else "not_configured",
        },
    }

    all_ok = all(
        v.get("status") in ("connected", "configured", "ok", "available")
        for v in services.values()
    )
    any_error = any(
        v.get("status") in ("disconnected", "not_configured", "error")
        for v in services.values()
    )

    return {
        "state": "healthy" if all_ok else ("warning" if not any_error else "degraded"),
        "services": services,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }
