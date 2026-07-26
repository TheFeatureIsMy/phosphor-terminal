import os
from datetime import datetime, timezone

from fastapi import APIRouter

from app.services.freqtrade_client import freqtrade_client
from app.schemas.api import SystemStatusResponse

router = APIRouter(prefix="/api/system", tags=["system"])


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

    return SystemStatusResponse(
        uptime="unknown" if not api_ok else "connected",
        active_strategies=2 if api_ok else 0,
        open_positions=open_pos,
        pending_orders=0,
        last_data_update=datetime.now(timezone.utc),
        api_status="connected" if api_ok else "disconnected",
        data_source={
            "source": "freqtrade" if api_ok else "unavailable",
            "simulated": False,
            "available": api_ok,
            "detail": detail,
        },
    )


@router.get("/dependencies")
async def get_dependencies():
    from app.services.dependency_checker import check_all_dependencies

    return check_all_dependencies()


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
