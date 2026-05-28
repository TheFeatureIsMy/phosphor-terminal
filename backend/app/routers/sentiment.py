from __future__ import annotations
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.models.strategy import SentimentData
from app.schemas.api import SentimentDataCreate, SentimentDataResponse
from app.services.sentiment_service import (
    analyze_sentiment,
    get_market_sentiment,
    get_sentiment_summary,
)

router = APIRouter(prefix="/sentiment", tags=["sentiment"])


class SentimentRequest(BaseModel):
    text: str


@router.post("/analyze")
def analyze(body: SentimentRequest):
    return analyze_sentiment(body.text)


@router.get("/market/{symbol}")
def market_sentiment(symbol: str, days: int = Query(default=7, ge=1, le=30)):
    return get_market_sentiment(symbol, days)


@router.get("/summary")
def summary():
    return get_sentiment_summary()


@router.post("/records", response_model=SentimentDataResponse, status_code=201)
def create_sentiment_record(body: SentimentDataCreate, db: Session = Depends(get_db)):
    item = SentimentData(**body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/records", response_model=list[SentimentDataResponse])
def list_sentiment_records(symbol: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(SentimentData)
    if symbol:
        query = query.filter(SentimentData.symbol == symbol)
    return query.order_by(SentimentData.timestamp.desc()).limit(100).all()
