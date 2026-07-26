# Tests for sentiment router, service, and FinBERT adapter (keyword fallback).
from __future__ import annotations

import pytest


class TestFinBERTAdapter:
    def test_positive_keywords(self):
        from app.services.sentiment_finbert import FinBERTAdapter
        adapter = FinBERTAdapter()
        result = adapter.analyze_text("profit growth bullish upgrade")
        assert result["label"] == "positive"
        assert result["score"] > 0
        assert result["model"] == "keyword_fallback"

    def test_negative_keywords(self):
        from app.services.sentiment_finbert import FinBERTAdapter
        adapter = FinBERTAdapter()
        result = adapter.analyze_text("loss decline bearish risk")
        assert result["label"] == "negative"
        assert result["score"] < 0
        assert result["model"] == "keyword_fallback"

    def test_neutral_no_keywords(self):
        from app.services.sentiment_finbert import FinBERTAdapter
        adapter = FinBERTAdapter()
        result = adapter.analyze_text("the weather is fine today")
        assert result["label"] == "neutral"
        assert result["score"] == 0.0

    def test_mixed_keywords_yield_neutral(self):
        from app.services.sentiment_finbert import FinBERTAdapter
        adapter = FinBERTAdapter()
        result = adapter.analyze_text("profit loss")
        assert result["label"] == "neutral"

    def test_model_loaded_is_bool(self):
        from app.services.sentiment_finbert import FinBERTAdapter
        adapter = FinBERTAdapter()
        assert isinstance(adapter.model_loaded, bool)


class TestAnalyzeSentiment:
    def test_returns_expected_keys(self):
        from app.services.sentiment_service import analyze_sentiment
        result = analyze_sentiment("profit growth bullish")
        assert set(result.keys()) == {
            "text", "sentiment", "score",
            "positive_prob", "negative_prob",
        }
        assert result["sentiment"] == "positive"

    def test_negative_text(self):
        from app.services.sentiment_service import analyze_sentiment
        result = analyze_sentiment("loss decline bearish risk")
        assert result["sentiment"] == "negative"

    def test_neutral_text(self):
        from app.services.sentiment_service import analyze_sentiment
        result = analyze_sentiment("hello world")
        assert result["sentiment"] == "neutral"

    def test_text_truncation(self):
        from app.services.sentiment_service import analyze_sentiment
        long_text = "profit " * 500
        result = analyze_sentiment(long_text)
        assert len(result["text"]) <= 200


class TestGetMarketSentiment:
    def test_returns_trend_data(self):
        from app.services.sentiment_service import get_market_sentiment
        result = get_market_sentiment("BTC/USDT", days=5)
        assert result["symbol"] == "BTC/USDT"
        assert result["period_days"] == 5
        assert len(result["trend"]) == 5
        for item in result["trend"]:
            assert "date" in item
            assert "score" in item
            assert "sentiment" in item
            assert 0 <= item["score"] <= 1

    def test_average_score_matches_trend(self):
        from app.services.sentiment_service import get_market_sentiment
        result = get_market_sentiment("ETH/USDT", days=3)
        expected = round(sum(d["score"] for d in result["trend"]) / 3, 3)
        assert result["average_score"] == expected

    def test_overall_sentiment_label(self):
        from app.services.sentiment_service import get_market_sentiment
        result = get_market_sentiment("SOL/USDT", days=7)
        avg = result["average_score"]
        if avg > 0.6:
            assert result["overall_sentiment"] == "positive"
        elif avg < 0.4:
            assert result["overall_sentiment"] == "negative"
        else:
            assert result["overall_sentiment"] == "neutral"


class TestGetSentimentSummary:
    def test_returns_four_symbols(self):
        from app.services.sentiment_service import get_sentiment_summary
        result = get_sentiment_summary()
        assert len(result["market_overview"]) == 4
        for item in result["market_overview"]:
            assert "symbol" in item
            assert "score" in item
            assert "sentiment" in item

    def test_has_fear_greed(self):
        from app.services.sentiment_service import get_sentiment_summary
        result = get_sentiment_summary()
        assert "fear_greed_index" in result
        assert 0 <= result["fear_greed_index"] <= 100
        assert result["fear_greed_label"] in ("恐惧", "中性", "贪婪")


class TestSentimentRouter:
    def test_analyze_endpoint(self, client):
        resp = client.post("/sentiment/analyze", json={"text": "profit growth bullish"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["sentiment"] == "positive"

    def test_market_sentiment_endpoint(self, client):
        resp = client.get("/sentiment/market/BTCUSDT?days=3")
        assert resp.status_code == 200
        data = resp.json()
        assert data["symbol"] == "BTCUSDT"
        assert data["period_days"] == 3
        assert len(data["trend"]) == 3

    def test_market_sentiment_invalid_days(self, client):
        resp = client.get("/sentiment/market/BTCUSDT?days=0")
        assert resp.status_code == 422

    def test_market_sentiment_days_too_large(self, client):
        resp = client.get("/sentiment/market/BTCUSDT?days=99")
        assert resp.status_code == 422

    def test_summary_endpoint_empty_db(self, client):
        resp = client.get("/sentiment/summary")
        assert resp.status_code == 200
        data = resp.json()
        assert "market_overview" in data
        assert "fear_greed_index" in data
        assert data["data_source"]["simulated"] is True

    def test_create_and_list_records(self, client):
        resp = client.post("/sentiment/records", json={
            "symbol": "BTC/USDT",
            "source": "news",
            "score": 0.85,
        })
        assert resp.status_code == 201
        created = resp.json()
        assert created["symbol"] == "BTC/USDT"
        assert created["score"] == 0.85
        assert "id" in created

        resp2 = client.get("/sentiment/records")
        assert resp2.status_code == 200
        records = resp2.json()
        assert len(records) >= 1
        assert records[0]["symbol"] == "BTC/USDT"

    def test_list_records_by_symbol(self, client):
        client.post("/sentiment/records", json={
            "symbol": "ETH/USDT", "source": "social", "score": 0.3,
        })
        client.post("/sentiment/records", json={
            "symbol": "BTC/USDT", "source": "social", "score": 0.7,
        })
        resp = client.get("/sentiment/records?symbol=ETH%2FUSDT")
        assert resp.status_code == 200
        records = resp.json()
        assert len(records) == 1
        assert records[0]["symbol"] == "ETH/USDT"

    def test_summary_with_db_records(self, client):
        for score in [0.8, 0.75, 0.7]:
            client.post("/sentiment/records", json={
                "symbol": "BTC/USDT", "source": "news", "score": score,
            })
        resp = client.get("/sentiment/summary")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["market_overview"]) >= 1
        btc = next(s for s in data["market_overview"] if s["symbol"] == "BTC/USDT")
        assert btc["sentiment"] == "positive"
        assert data["data_source"]["simulated"] is False
