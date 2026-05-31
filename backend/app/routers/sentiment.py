from __future__ import annotations
from datetime import datetime, timezone
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
def summary(db: Session = Depends(get_db)):
    from app.services.freqtrade_db import freqtrade_db
    records = db.query(SentimentData).order_by(SentimentData.timestamp.desc()).limit(100).all()
    if not records:
        result = get_sentiment_summary()
        result["data_source"] = freqtrade_db.source_status(simulated=True)
        return result
    symbols = list(set(r.symbol for r in records))
    by_symbol: dict[str, list[float]] = {s: [] for s in symbols}
    for r in records:
        by_symbol[r.symbol].append(r.score)
    sentiments = []
    for sym in symbols:
        scores = by_symbol[sym]
        avg = sum(scores) / len(scores)
        sentiments.append({
            "symbol": sym,
            "score": round(avg, 3),
            "sentiment": "positive" if avg > 0.6 else ("negative" if avg < 0.4 else "neutral"),
            "change_24h": 0,
        })
    all_scores = [r.score for r in records]
    avg_all = sum(all_scores) / len(all_scores) if all_scores else 0.5
    return {
        "market_overview": sentiments,
        "fear_greed_index": round(avg_all * 100),
        "fear_greed_label": "贪婪" if avg_all > 0.6 else ("恐惧" if avg_all < 0.4 else "中性"),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "data_source": freqtrade_db.source_status(simulated=False),
    }


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
