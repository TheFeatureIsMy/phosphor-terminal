"""Sentiment router — PRD §9.4 market sentiment endpoints.

Primary prefix is /api/sentiment (PRD-compliant). The legacy /sentiment
prefix is kept as a deprecated alias until the macOS client migrates.
"""
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

router = APIRouter(prefix="/api/sentiment", tags=["sentiment"])
legacy_router = APIRouter(prefix="/sentiment", tags=["sentiment-legacy"], include_in_schema=False)

_NEWS_SOURCES = {"news", "rss", "coindesk", "theblock", "headline"}
_SOCIAL_SOURCES = {"social", "twitter", "x", "reddit", "telegram"}


class SentimentRequest(BaseModel):
    text: str


def _records_by_sources(db: Session, sources: set[str], source_type: str, limit: int) -> dict:
    """Aggregate sentiment records for a source family; honest empty state when none."""
    records = (
        db.query(SentimentData)
        .filter(SentimentData.source.in_(list(sources)))
        .order_by(SentimentData.timestamp.desc())
        .limit(limit)
        .all()
    )
    if not records:
        return {
            "state": "data_source_unavailable",
            "reason_codes": [f"{source_type}_records_empty"],
            "available_actions": [],
            "items": [],
        }
    avg = sum(r.score for r in records) / len(records)
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "average_score": round(avg, 3),
        "count": len(records),
        "items": [
            {
                "symbol": r.symbol,
                "source": r.source,
                "score": r.score,
                "text": (r.raw_text or "")[:200],
                "timestamp": r.timestamp.isoformat() if r.timestamp else None,
            }
            for r in records
        ],
    }


@router.post("/analyze")
def analyze(body: SentimentRequest):
    return analyze_sentiment(body.text)


@router.get("/market")
def market_global(db: Session = Depends(get_db)):
    """Global market sentiment aggregated from persisted records."""
    records = db.query(SentimentData).order_by(SentimentData.timestamp.desc()).limit(200).all()
    if not records:
        return {
            "state": "data_source_unavailable",
            "reason_codes": ["sentiment_records_empty"],
            "available_actions": [],
            "market_overview": [],
        }
    by_symbol: dict[str, list[float]] = {}
    for r in records:
        by_symbol.setdefault(r.symbol, []).append(r.score)
    overview = [
        {
            "symbol": sym,
            "score": round(sum(scores) / len(scores), 3),
            "count": len(scores),
        }
        for sym, scores in by_symbol.items()
    ]
    all_scores = [r.score for r in records]
    avg_all = sum(all_scores) / len(all_scores)
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "market_overview": overview,
        "fear_greed_index": round(avg_all * 100),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/market/{symbol}")
def market_sentiment(symbol: str, days: int = Query(default=7, ge=1, le=30)):
    return get_market_sentiment(symbol, days)


@router.get("/symbol/{symbol}")
def symbol_sentiment(symbol: str, days: int = Query(default=7, ge=1, le=30)):
    """PRD §9.4 per-symbol endpoint (alias of /market/{symbol})."""
    return get_market_sentiment(symbol, days)


@router.get("/news")
def news_sentiment(db: Session = Depends(get_db), limit: int = Query(default=50, ge=1, le=200)):
    return _records_by_sources(db, _NEWS_SOURCES, "news", limit)


@router.get("/social")
def social_sentiment(db: Session = Depends(get_db), limit: int = Query(default=50, ge=1, le=200)):
    return _records_by_sources(db, _SOCIAL_SOURCES, "social", limit)


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


# ── Legacy /sentiment alias (deprecated, kept for the current macOS client) ──

legacy_router.post("/analyze")(analyze)
legacy_router.get("/market/{symbol}")(market_sentiment)
legacy_router.get("/summary")(summary)
legacy_router.post("/records", response_model=SentimentDataResponse, status_code=201)(create_sentiment_record)
legacy_router.get("/records", response_model=list[SentimentDataResponse])(list_sentiment_records)
