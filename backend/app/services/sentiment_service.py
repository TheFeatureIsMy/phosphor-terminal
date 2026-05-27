"""
FinBERT sentiment analysis service.
In production, this would use the actual FinBERT model.
Currently provides simulated sentiment data for development.
"""
import random
from datetime import datetime, timedelta, timezone
from typing import Any


def analyze_sentiment(text: str) -> dict[str, Any]:
    """
    Analyze sentiment of financial text.
    Returns sentiment label and confidence score.
    """
    # Simulated FinBERT-like analysis
    positive_words = ["bullish", "surge", "rally", "gain", "growth", "profit", "breakout", "upgrade"]
    negative_words = ["bearish", "crash", "drop", "loss", "decline", "sell-off", "downgrade", "risk"]

    text_lower = text.lower()
    pos_count = sum(1 for w in positive_words if w in text_lower)
    neg_count = sum(1 for w in negative_words if w in text_lower)

    if pos_count > neg_count:
        sentiment = "positive"
        score = min(0.6 + pos_count * 0.1, 0.95)
    elif neg_count > pos_count:
        sentiment = "negative"
        score = min(0.6 + neg_count * 0.1, 0.95)
    else:
        sentiment = "neutral"
        score = 0.5 + random.random() * 0.2

    return {
        "text": text[:200],
        "sentiment": sentiment,
        "score": round(score, 3),
        "positive_prob": round(score if sentiment == "positive" else 1 - score, 3),
        "negative_prob": round(1 - score if sentiment == "positive" else score, 3),
    }


def get_market_sentiment(symbol: str = "BTC/USDT", days: int = 7) -> dict[str, Any]:
    """
    Get aggregated market sentiment for a symbol over time.
    """
    now = datetime.now(timezone.utc)
    trend_data = []
    base_score = 0.55

    for i in range(days):
        date = now - timedelta(days=days - 1 - i)
        noise = random.gauss(0, 0.08)
        base_score = max(0.2, min(0.85, base_score + noise))
        trend_data.append({
            "date": date.strftime("%Y-%m-%d"),
            "score": round(base_score, 3),
            "sentiment": "positive" if base_score > 0.6 else ("negative" if base_score < 0.4 else "neutral"),
            "volume": random.randint(100, 500),
        })

    avg_score = sum(d["score"] for d in trend_data) / len(trend_data)

    return {
        "symbol": symbol,
        "period_days": days,
        "average_score": round(avg_score, 3),
        "overall_sentiment": "positive" if avg_score > 0.6 else ("negative" if avg_score < 0.4 else "neutral"),
        "trend": trend_data,
        "sources": {
            "news": random.randint(50, 200),
            "social": random.randint(100, 500),
            "analyst": random.randint(10, 50),
        },
    }


def get_sentiment_summary() -> dict[str, Any]:
    """
    Get overall market sentiment summary across major pairs.
    """
    symbols = ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT"]
    sentiments = []

    for sym in symbols:
        data = get_market_sentiment(sym, 3)
        sentiments.append({
            "symbol": sym,
            "score": data["average_score"],
            "sentiment": data["overall_sentiment"],
            "change_24h": round(random.gauss(0, 0.05), 3),
        })

    return {
        "market_overview": sentiments,
        "fear_greed_index": random.randint(20, 80),
        "fear_greed_label": random.choice(["恐惧", "中性", "贪婪"]),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
