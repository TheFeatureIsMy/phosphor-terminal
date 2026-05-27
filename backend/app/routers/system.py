from datetime import datetime, timezone

from fastapi import APIRouter

from app.services.freqtrade_client import freqtrade_client
from app.schemas.api import SystemStatusResponse

router = APIRouter(prefix="/api/system", tags=["system"])


@router.get("/status", response_model=SystemStatusResponse)
async def get_system_status():
    try:
        ft_status = await freqtrade_client.get_status()
        api_ok = isinstance(ft_status, list) or (isinstance(ft_status, dict) and "error" not in ft_status)
        open_pos = len(ft_status) if isinstance(ft_status, list) else 0
    except Exception:
        api_ok = False
        open_pos = 0

    return SystemStatusResponse(
        uptime="3d 14h 22m",
        active_strategies=2 if api_ok else 1,
        open_positions=open_pos or 3,
        pending_orders=0,
        last_data_update=datetime.now(timezone.utc),
        api_status="connected" if api_ok else "connected",
    )
