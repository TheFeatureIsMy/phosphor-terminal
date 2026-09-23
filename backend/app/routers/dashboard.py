from fastapi import APIRouter

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import DashboardKPIsResponse, EquityPointResponse

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("/kpis", response_model=DashboardKPIsResponse)
def get_kpis():
    """Return real KPIs from the Freqtrade trade database.

    Mock-removal policy: when the trade DB is unavailable or has no trades we
    return the real (zero) values with an explicit `data_source` marker, NOT a
    hardcoded simulated payload — fabricated PnL would mislead trading decisions.
    """
    result = freqtrade_db.get_kpis()
    result["data_source"] = freqtrade_db.source_status()
    return result


@router.get("/equity-curve", response_model=list[EquityPointResponse])
def get_equity_curve():
    """Return the real equity curve; empty when there are no closed trades.

    An empty list lets the frontend render its "暂无曲线数据" empty state instead
    of a fabricated curve.
    """
    result = freqtrade_db.get_equity_curve()
    source = freqtrade_db.source_status()
    for point in result:
        point["data_source"] = source
    return result
