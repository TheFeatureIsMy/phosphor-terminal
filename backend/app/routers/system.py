from datetime import datetime

from fastapi import APIRouter

from app.services.freqtrade_client import freqtrade_client
from app.schemas.api import SystemStatusResponse

router = APIRouter(prefix="/api/system", tags=["system"])


@router.get("/status", response_model=SystemStatusResponse)
async def get_system_status():
    ft_status = await freqtrade_client.get_status()
    # Freqtrade returns a list of trades on success, dict with "error" on failure
    api_ok = isinstance(ft_status, list) or (isinstance(ft_status, dict) and "error" not in ft_status)
    open_pos = len(ft_status) if isinstance(ft_status, list) else 0
    return SystemStatusResponse(
        uptime="0d 0h 0m",
        active_strategies=1 if api_ok else 0,
        open_positions=open_pos,
        pending_orders=0,
        last_data_update=datetime.utcnow(),
        api_status="connected" if api_ok else "disconnected",
    )
