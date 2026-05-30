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
