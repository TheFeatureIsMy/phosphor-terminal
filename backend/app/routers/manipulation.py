"""Manipulation Radar API — scan + score retrieval."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.manipulation import ManipulationScanRequest, ManipulationScoreResponse
from app.services.manipulation.radar_service import ManipulationRadarService

router = APIRouter(prefix="/api/v2/manipulation", tags=["manipulation-radar"])


@router.post("/scan", response_model=ManipulationScoreResponse, status_code=201)
def scan_symbol(req: ManipulationScanRequest, db: Session = Depends(get_db)):
    svc = ManipulationRadarService(db)
    svc.scan_symbol(req.symbol, req.timeframe)
    db.commit()

    record = svc.get_latest_score(req.symbol)
    if not record:
        raise HTTPException(status_code=500, detail="Failed to persist score")
    return ManipulationScoreResponse.from_orm_model(record)


@router.get("/scores", response_model=list[ManipulationScoreResponse])
def list_scores(
    risk_level: str | None = None,
    limit: int = Query(default=50, le=200),
    db: Session = Depends(get_db),
):
    svc = ManipulationRadarService(db)
    records = svc.list_scores(risk_level=risk_level, limit=limit)
    return [ManipulationScoreResponse.from_orm_model(r) for r in records]


@router.get("/scores/{symbol:path}", response_model=ManipulationScoreResponse)
def get_symbol_score(symbol: str, db: Session = Depends(get_db)):
    svc = ManipulationRadarService(db)
    record = svc.get_latest_score(symbol)
    if not record:
        raise HTTPException(status_code=404, detail=f"No score found for {symbol}")
    return ManipulationScoreResponse.from_orm_model(record)
