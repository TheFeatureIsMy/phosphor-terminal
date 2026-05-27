from __future__ import annotations
from fastapi import APIRouter, Query
from pydantic import BaseModel
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
