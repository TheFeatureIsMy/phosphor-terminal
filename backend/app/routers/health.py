from fastapi import APIRouter

from app.config import settings
from app.database import check_db
from app.schemas.health import HealthResponse, ReadinessResponse
from app.services.freqtrade_client import freqtrade_client

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health():
    return HealthResponse(status="ok", version="2.5.0")


async def _redis_ready() -> bool:
    if not settings.redis_url:
        return False
    client = None
    try:
        import redis.asyncio as aioredis

        client = aioredis.from_url(settings.redis_url, decode_responses=True)
        return bool(await client.ping())
    except Exception:
        return False
    finally:
        if client is not None:
            try:
                await client.aclose()
            except Exception:
                pass


@router.get("/readiness", response_model=ReadinessResponse)
async def readiness():
    """Deploy probe: DB and Redis are required, Freqtrade is reported separately."""
    db_ok = check_db()
    redis_ok = await _redis_ready()
    try:
        freqtrade_ok = await freqtrade_client.ping()
    except Exception:
        freqtrade_ok = False

    reasons: list[str] = []
    if not db_ok:
        reasons.append("database_unavailable")
    if not redis_ok:
        reasons.append("redis_unavailable")
    if not freqtrade_ok:
        reasons.append("freqtrade_unavailable")

    return ReadinessResponse(
        status="ready" if db_ok and redis_ok else "not_ready",
        database="connected" if db_ok else "disconnected",
        redis="connected" if redis_ok else "disconnected",
        freqtrade="connected" if freqtrade_ok else "disconnected",
        reason_codes=reasons,
    )
