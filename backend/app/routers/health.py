from fastapi import APIRouter

from app.database import check_db
from app.schemas.health import HealthResponse, ReadinessResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health():
    return HealthResponse(status="ok", version="2.5.0")


@router.get("/readiness", response_model=ReadinessResponse)
def readiness():
    db_ok = check_db()
    return ReadinessResponse(
        status="ready" if db_ok else "not_ready",
        database="connected" if db_ok else "disconnected",
    )
