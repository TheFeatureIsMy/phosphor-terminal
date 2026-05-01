from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import RiskEvent, CorrelationSnapshot
from app.schemas.api import RiskEventResponse, CorrelationResponse

router = APIRouter(prefix="/api", tags=["risk"])


@router.get("/risk/events", response_model=list[RiskEventResponse])
def list_risk_events(db: Session = Depends(get_db)):
    return db.query(RiskEvent).order_by(RiskEvent.created_at.desc()).limit(50).all()


@router.get("/portfolio/correlation", response_model=list[CorrelationResponse])
def list_correlations(db: Session = Depends(get_db)):
    return db.query(CorrelationSnapshot).all()
